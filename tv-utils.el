;;; tv-utils.el --- Some useful functions for Emacs. -*- lexical-binding: t -*- 
;; 

;;; Code:

(require 'cl-lib)

(declare-function helm-find-files-1             "ext:helm-files.el")
(declare-function mailcap-extension-to-mime     "mailcap.el")
(declare-function htmlize-file                  "htmlize.el")
(declare-function calendar-exit                 "calendar.el")
(declare-function helm-region-active-p          "ext:helm-lib.el")
(declare-function helm-basename                 "ext:helm-lib.el")
(declare-function helm-read-file-name           "ext:helm-mode.el")
(declare-function common-lisp-indent-function-1 "cl-indent.el")
(declare-function tv/get-disk-info              "ext:dired-extension.el")
(declare-function iterator:circular             "ext:iterator.el")
(declare-function iterator:next                 "ext:iterator.el")
(declare-function helm-fast-remove-dups         "ext:helm-lib.el")
(declare-function auth-source-search            "auth-source.el")
(declare-function eshell-interactive-process    "esh-cmd.el")
(declare-function which-function                "which-func.el")
(declare-function helm--ansi-color-apply        "ext:helm-lib.el")


;;; Sshfs
;;
;;
;;;###autoload
(defun mount-sshfs (fs mp)
  (interactive (list (completing-read "FileSystem: "
                                      '("thievol:/home/thierry"
                                        "thievolrem:/home/thierry"
                                        "zte:/"))
                     (expand-file-name
                      (read-directory-name "MountPoint: "
                                           "/home/thierry/"
                                           "/home/thierry/sshfs/"
                                           t
                                           "sshfs"))))
  (if (> (length (directory-files
                  mp nil directory-files-no-dot-files-regexp)) 0)
      (message "Directory %s is busy, mountsshfs aborted" mp)
      (if (= (call-process-shell-command
              (format "sshfs %s %s" fs mp) nil t nil)
             0)
          (message "%s Mounted successfully on %s" fs mp)
          (message "Failed to mount remote filesystem %s on %s" fs mp))))

;;;###autoload
(defun umount-sshfs (mp)
  (interactive (list (expand-file-name
                      (read-directory-name "MountPoint: "
                                           "/home/thierry/"
                                           "/home/thierry/sshfs/"
                                           t
                                           "sshfs"))))
  (if (equal (pwd) (format "Directory %s" mp))
      (message "Filesystem is busy can't umount!")
      (progn
        (if (>= (length (cddr (directory-files mp))) 0)
            (if (= (call-process-shell-command
                    (format "fusermount -u %s" mp) nil t nil)
                   0)
                (message "%s Successfully unmounted" mp)
                (message "Failed to unmount %s" mp))
            (message "No existing remote filesystem to unmount!")))))

;;;###autoload
(defun sshfs-connect ()
  "sshfs mount of thievol."
  (interactive)
  (mount-sshfs "thievol:" "~/sshfs")
  (helm-find-files-1 "~/sshfs"))

;;;###autoload
(defun sshfs-disconnect ()
  "sshfs umount of thievol."
  (interactive)
  (umount-sshfs "~/sshfs"))

;; get-ip 
;; get my external ip
;;;###autoload
(defun get-external-ip ()
  (interactive)
  (with-current-buffer (url-retrieve-synchronously "http://checkip.dyndns.org/")
    (let ((data (xml-parse-region (point-min) (point-max))))
      (car (last
            (split-string
             (car (last (assoc 'body (assoc 'html data))))))))))

;; network-info 
(defun tv/network-info (network)
  (let ((info (cl-loop for (i . n) in (network-interface-list)
                       when (string= network i)
                       return (network-interface-info i))))
    (when info
      (cl-destructuring-bind (address broadcast netmask mac state)
          info
        (list :address address :broadcast broadcast
              :netmask netmask :mac (cdr mac) :state state)))))

;;;###autoload
(defun tv/network-state (network &optional arg)
  (interactive (list (read-string "Network: " "wlan0")
                     "\np"))
  (let* ((info (car (last (cl-getf (tv/network-info network) :state))))
         (state (if info (symbol-name info) "down")))
    (if arg (message "%s is %s" network state) state)))

;; Benchmark
(defmacro tv/time (&rest body)
  "Return a list (time result) of time execution of BODY and result of BODY."
  (declare (indent 0))
  `(let ((tm (float-time)))
     (reverse
      (list
       ,@body
       (- (float-time) tm)))))

;; Show-current-face 
;;;###autoload
(defun whatis-face ()
  (interactive)
  (message "CurrentFace: %s"
           (get-text-property (point) 'face)))

;; mcp 
;;;###autoload
(defun tv/mcp (file &optional dests)
  "Copy FILE in DESTS directories."
  (interactive "fFile: ")
  (unless dests
    (setq dests
          (helm-read-file-name "Directory: "
                               :marked-candidates t
                               :test 'file-directory-p
                               :noret t)))
  (cl-loop for dir in dests
           do
           (copy-file file (file-name-as-directory dir) t)))

;;; move-to-window-line 
;;
;;;###autoload
(defun screen-top (&optional n)
  "Move the point to the top of the screen."
  (interactive "p")
  (move-to-window-line (or n 0)))

;;;###autoload
(defun screen-bottom (&optional n)
  "Move the point to the bottom of the screen."
  (interactive "P")
  (move-to-window-line (- (prefix-numeric-value n))))

;;; switch-other-window 
;;
;;;###autoload
(defun other-window-backward (&optional n)
  "Move backward to other window or frame."
  (interactive "p")
  (other-window (- n) 0)
  (select-frame-set-input-focus (selected-frame)))

;;;###autoload
(defun other-window-forward (&optional n)
  "Move to other window or frame.
With a prefix arg move N window forward or backward
depending the value of N is positive or negative."
  (interactive "p")
  (other-window n 0)
  (select-frame-set-input-focus (selected-frame)))

;;; Stardict
;;
;;;###autoload
(defun translate-at-point (arg)
  (interactive "P")
  (let* ((word (if arg
                   (read-string "Translate Word: ")
                   (thing-at-point 'word)))
         (tooltip-hide-delay 30)
         (result
          (condition-case nil
              (shell-command-to-string (format "LC_ALL=\"fr_FR.UTF-8\" sdcv -n %s" word))
            (error nil))))
    (setq result (replace-regexp-in-string "^\\[ color=\"blue\">\\|</font>\\|\\]" "" result))
    (if result
        (with-current-buffer (get-buffer-create "*Dict*")
          (erase-buffer)
          (save-excursion
            (insert result) (fill-region (point-min) (point-max)))
          ;; Assume dict buffer is in `special-display-buffer-names'.
          (switch-to-buffer-other-frame "*Dict*")
          (view-mode 1))
        (message "Nothing found."))))

;;; Get-mime-type-of-file
;;
;;;###autoload
(defun file-mime-type (fname &optional arg)
  "Get the mime-type of fname"
  (interactive "fFileName: \np")
  (if arg
      (message "%s" (mailcap-extension-to-mime (file-name-extension fname t)))
      (mailcap-extension-to-mime (file-name-extension fname t))))

;;; Eval-region
;;
;;
;;;###autoload
(defun tv/eval-region (beg end)
  (interactive "r")
  (let ((str (buffer-substring beg end))
        expr
        store)
    (with-temp-buffer
      (save-excursion
        (insert str))
      (condition-case _err
          (while (setq expr (read (current-buffer)))
            (push (eval expr) store))
        (end-of-file nil)))
    (message "Evaluated in Region:\n- %s"
             (mapconcat 'identity
                        (mapcar #'(lambda (x)
                                    (format "`%s'" x))
                                (reverse store))
                        "\n- "))))

;;; Time-functions 
(cl-defun tv/time-date-in-n-days (days &key (separator "-") french)
  "Return the date in string form in n +/-DAYS."
  (let* ((days-in-sec       (* 3600 (* (+ days) 24)))
         (interval-days-sec (if (< days 0)
                                (+ (float-time (current-time)) days-in-sec)
                                (- (float-time (current-time)) days-in-sec)))
         (sec-to-time       (seconds-to-time interval-days-sec))
         (time-dec          (decode-time sec-to-time))
         (year              (int-to-string (nth 5 time-dec)))
         (month             (if (= (% (nth 4 time-dec) 10) 0)
                                (int-to-string (nth 4 time-dec))
                                (substring (int-to-string (/ (float (nth 4 time-dec)) 100)) 2)))
         (day-str           (if (= (% (nth 3 time-dec) 10) 0)
                                (int-to-string (nth 3 time-dec))
                                (substring (int-to-string (/ (float (nth 3 time-dec)) 100)) 2)))
         (day               (if (< (length day-str) 2) (concat day-str "0") day-str))
         (result            (list year month day)))
    (if french
        (mapconcat 'identity (reverse result) separator)
        (mapconcat 'identity result separator))))

;; mapc-with-progress-reporter 
(defmacro mapc-with-progress-reporter (message func seq)
  `(let* ((max               (length ,seq))
          (progress-reporter (make-progress-reporter (message ,message) 0 max))
          (count             0))
     (mapc #'(lambda (x)
               (progress-reporter-update progress-reporter count)
               (funcall ,func x)
               (cl-incf count))
           ,seq)
     (progress-reporter-done progress-reporter)))

;; Send current buffer htmlized to web browser.
;;;###autoload
(defun tv/htmlize-buffer-to-browser ()
  (interactive)
  (let* ((fname           (concat "/tmp/" (symbol-name (cl-gensym "emacs2browser"))))
         (html-fname      (concat fname ".html"))
         (buffer-contents (buffer-substring (point-min) (point-max))))
    (with-current-buffer (find-file-noselect fname)
      (insert buffer-contents)
      (save-buffer)
      (kill-buffer))
    (htmlize-file fname html-fname)
    (browse-url (format "file://%s" html-fname))))

;; key-for-calendar 
(defvar tv/calendar-alive nil)
;;;###autoload
(defun tv/toggle-calendar ()
  (interactive)
  (if tv/calendar-alive
      (when (get-buffer "*Calendar*")
        (with-current-buffer "diary" (save-buffer)) 
        (calendar-exit)) ; advice reset win conf
      ;; In case calendar were called without toggle command
      (unless (get-buffer-window "*Calendar*")
        (setq tv/calendar-alive (current-window-configuration))
        (calendar))))

(defadvice calendar-exit (after reset-win-conf activate)
  (when tv/calendar-alive
    (set-window-configuration tv/calendar-alive)
    (setq tv/calendar-alive nil)))

;;; Insert-pairs 
;;
(setq parens-require-spaces t)

;;;###autoload
(defun tv/insert-double-quote (&optional arg)
  (interactive "P")
  (insert-pair arg ?\" ?\"))

;;;###autoload
(defun tv/insert-double-backquote (&optional arg)
  (interactive "P")
  (insert-pair arg ?\` (if (or (eq major-mode 'emacs-lisp-mode)
                               (eq major-mode 'lisp-interaction-mode))
                           ?\' ?\`)))

;;;###autoload
(defun tv/insert-vector (&optional arg)
  (interactive "P")
  (insert-pair arg ?\[ ?\]))

;;;###autoload
(defun tv/move-pair-forward (beg end)
  (interactive "r")
  (if (region-active-p)
      (progn (goto-char beg) (insert "(")
             (goto-char (1+ end)) (insert ")"))
      (let (action kb com)
        (catch 'break
          (while t
            (setq action (read-key "`(': Insert, (any key to exit)."))
            (cl-case action
              (?\(
               (skip-chars-forward " \n")
               (insert "(")
               (forward-sexp 1)
               (insert ")"))
              (t (setq kb  (this-command-keys-vector))
                 (setq com (lookup-key (current-local-map) kb))
                 (if (commandp com)
                     (call-interactively com)
                     (setq unread-command-events
                           (nconc (mapcar 'identity
                                          (this-single-command-raw-keys))
                                  unread-command-events)))
                 (throw 'break nil))))))))

;;;###autoload
(defun tv/insert-pair-and-close-forward (beg end)
  (interactive "r")
  (if (region-active-p)
      (progn (goto-char beg) (insert "(")
             (goto-char (1+ end)) (insert ")"))
      (let (action kb com)
        (insert "(")
        (catch 'break
          (while t
            (setq action (read-key "`)': Insert, (any key to exit)."))
            (cl-case action
              (?\)
               (unless (looking-back "(" (1- (point)))
                 (delete-char -1))
               (skip-chars-forward " ")
               (forward-symbol 1)
               ;; move forward in a list of strings
               (skip-chars-forward "\"")
               (insert ")"))
              (t (setq kb  (this-command-keys-vector))
                 (setq com (lookup-key (current-local-map) kb))
                 (if (commandp com)
                     (call-interactively com)
                     (setq unread-command-events
                           (nconc (mapcar 'identity
                                          (this-single-command-raw-keys))
                                  unread-command-events)))
                 (throw 'break nil))))))))

;;;###autoload
(defun tv/insert-double-quote-and-close-forward (beg end)
  (interactive "r")
  (if (region-active-p)
      (progn (goto-char beg) (insert "\"")
             (goto-char (1+ end)) (insert "\""))
      (let (action kb com
            (prompt (and (not (minibufferp))
                         "\": Insert, (any key to exit).")))
        (unless prompt (message "\": Insert, (any key to exit)."))
        (catch 'break
          (while t
            (setq action (read-key prompt))
            (cl-case action
              (?\"
               (skip-chars-forward " \n")
               (insert "\"")
               (forward-sexp 1)
               (insert "\""))
              (t (setq kb  (this-command-keys-vector))
                 (setq com (lookup-key (current-local-map) kb))
                 (if (commandp com)
                     (call-interactively com)
                     (setq unread-command-events
                           (nconc (mapcar 'identity
                                          (this-single-command-raw-keys))
                                  unread-command-events)))
                 (throw 'break nil))))))))

;;; Insert-an-image-at-point
;;;###autoload
(defun tv/insert-image-at-point (image)
  (interactive (list (read-file-name "Image: " "~/Images")))
  (let* ((win (selected-window))
         (img (save-match-data
                (apply #'create-image image
                       (and (image-type-available-p 'imagemagick)
                            `(imagemagick nil :height ,(* (- (window-height win) 1)
                                                          (frame-char-height))))))))
    (insert-image img)))

;;;###autoload
(defun tv/show-img-from-fname-at-point ()
  (interactive)
  (let ((img (thing-at-point 'sexp)))
    (forward-line)
    (tv/insert-image-at-point img)))

(defun tv/view-echo-area-messages (old--fn &rest args)
  (let ((win (get-buffer-window (messages-buffer) 'visible)))
    (if win
        (quit-window nil win)
      (apply old--fn args))))

;; Kill-backward
;;;###autoload
(defun tv/kill-whole-line (&optional arg)
  "Similar to `kill-whole-line' but don't kill new line.
Also alow killing whole line in a shell prompt without trying
to kill prompt.
When called non interactively, do not delete empty line.
Can be used from any place in the line."
  (interactive "p")
  (end-of-line)
  (let ((end (point)) beg)
    (forward-line 0)
    (while (get-text-property (point) 'read-only)
      (forward-char 1))
    (setq beg (point)) (kill-region beg end))
  (when (and arg (eq (point-at-bol) (point-at-eol)))
    (delete-blank-lines) (skip-chars-forward " ")))

;; Kill-line
;;;###autoload
(defun tv/kill-line ()
  "Like kill-line but when at eol delete whole line.
Ignore text read-only at bol i.e. prompts."
  (interactive)
  (if (eolp)
      (tv/kill-whole-line)
    (kill-line)))

;; Delete-char-or-region
;;;###autoload
(defun tv/delete-char (arg)
  (interactive "p")
  (if (helm-region-active-p)
      (delete-region (region-beginning) (region-end))
      (delete-char arg)))

;; Easypg
(defvar epa-armor)
;;;###autoload
(defun epa-sign-to-armored ()
  "Create a .asc file."
  (interactive)
  (let ((epa-armor t))
    (call-interactively 'epa-sign-file)))

;; Same as above but usable as alias in eshell
;;;###autoload
(defun gpg-sign-to-armored (file)
  "Create a .asc file."
  (let ((epa-armor t))
    (epa-sign-file file nil nil)))

;; Usable from eshell as alias
;;;###autoload
(defun gpg-sign-to-sig (file)
  "Create a .sig file."
  (epa-sign-file file nil 'detached))

;;;###autoload
(defun tv/gpg-verify-file (gpg-file)
  "Meant to be used from eshell alias.
    alias gpg-verify tv/gpg-verify-file $1"
  (let ((data-file (directory-files
                    (file-name-directory (expand-file-name gpg-file)) t
                    (concat (regexp-quote (helm-basename gpg-file t)) "$"))))
    (cl-assert (member (file-name-extension gpg-file) '("gpg" "sig" "asc"))
               nil "Please select the signed file not the data file")
    (cl-assert (null (cdr data-file)) nil "Failed to find data-file")
    (setq data-file (car data-file))
    (with-temp-buffer
      (if (= (call-process "gpg" nil t nil "--verify" gpg-file data-file) 0)
          (buffer-string)
        "Gpg error while verifying signature"))))

;; Insert-log-from-patch
;;;###autoload
(defun tv/insert-log-from-patch (patch)
  (interactive (list (helm-read-file-name
                      "Patch: "
                      :preselect ".*[Pp]atch.*")))
  (let (beg end data)
    (with-current-buffer (find-file-noselect patch)
      (goto-char (point-min))
      (while (re-search-forward "^#" nil t) (forward-line 1))
      (setq beg (point))
      (when (re-search-forward "^diff" nil t)
        (forward-line 0) (skip-chars-backward "\\s*|\n*")
        (setq end (point)))
      (setq data (buffer-substring beg end))
      (kill-buffer))
    (insert data)
    (delete-file patch)))

;; Switch indenting lisp style.
;;;###autoload
(defun toggle-lisp-indent ()
  (interactive)
  (if (memq lisp-indent-function '(common-lisp-indent-function
                                   common-lisp-indent-function-1))
      (progn
        (setq lisp-indent-function #'lisp-indent-function)
        (message "Switching to Emacs lisp indenting style."))
    (setq lisp-indent-function #'common-lisp-indent-function-1)
    (message "Switching to Common lisp indenting style.")))

;; C-mode conf
(defvar c-mode-map)
;;;###autoload
(defun tv/cc-this-file ()
  (interactive)
  (when (eq major-mode 'c-mode)
    (let* ((iname (buffer-file-name (current-buffer)))
           (oname (file-name-sans-extension iname)))
      (compile (format "make -k %s" oname)))))
(add-hook 'c-mode-hook #'(lambda ()
                           (declare (special c-mode-map))
                           (define-key c-mode-map (kbd "C-c C-c") 'tv/cc-this-file)))

;; Insert line numbers in region
;;;###autoload
(defun tv/insert-lineno-in-region (beg end)
  (interactive "r")
  (save-restriction
    (narrow-to-region beg end)
    (goto-char (point-min))
    (cl-loop while (re-search-forward "^.*$" nil t)
             for count from 1 do
             (replace-match
              (concat (format "%d " count) (match-string 0))))))

;; Permutations (Too slow)

(cl-defun permutations (bag &key result-as-string print)
  "Return a list of all the permutations of the input."
  ;; If the input is nil, there is only one permutation:
  ;; nil itself
  (when (stringp bag) (setq bag (split-string bag "" t)))
  (let ((result
         (if (null bag)
             '(())
             ;; Otherwise, take an element, e, out of the bag.
             ;; Generate all permutations of the remaining elements,
             ;; And add e to the front of each of these.
             ;; Do this for all possible e to generate all permutations.
             (cl-loop for e in bag append
                      (cl-loop for p in (permutations (remove e bag))
                               collect (cons e p))))))
    (when (or result-as-string print)
      (setq result (cl-loop for i in result collect (mapconcat 'identity i ""))))
    (if print
        (with-current-buffer (get-buffer-create "*permutations*")
          (erase-buffer)
          (cl-loop for i in result
                   do (insert (concat i "\n")))
          (pop-to-buffer (current-buffer)))
        result)))

;; Verlan.
;;;###autoload
(defun tv/reverse-chars-in-region (beg end)
  "Verlan region. Unuseful but funny"
  (interactive "r")
  (save-restriction
    (narrow-to-region beg end)
    (goto-char (point-min))
    (while (not (eobp))
      (let* ((bl (point-at-bol))
             (el (point-at-eol))
             (cur-line (buffer-substring bl el))
             (split (cl-loop for i across cur-line collect i)))
        (delete-region bl el)
        (cl-loop for i in (reverse split) do (insert i)))
      (forward-line 1))))

;; Interface to df command-line.
;;
;;;###autoload
(defun dfh (directory)
  "Interface to df -h command line.
If a prefix arg is given choose directory, otherwise use `default-directory'."
  (interactive (list (if current-prefix-arg
                         (helm-read-file-name
                          "Directory: " :test 'file-directory-p)
                         default-directory)))
  (require 'dired-extension) ; for tv/get-disk-info
  (let ((df-info (tv/get-disk-info directory t)))
    (pop-to-buffer (get-buffer-create "*df info*"))
    (erase-buffer)
    (insert (format "*Volume Info for `%s'*\n\nDevice: %s\nMaxSize: \
%s\nUsed: %s\nAvailable: %s\nCapacity in use: %s\nMount point: %s"
                    directory
                    (cl-getf df-info :device)
                    (cl-getf df-info :blocks)
                    (cl-getf df-info :used)
                    (cl-getf df-info :available)
                    (cl-getf df-info :capacity)
                    (cl-getf df-info :mount-point)))
    (view-mode 1)))

;; Interface to du (directory size)
;;;###autoload
(defun duh (directory)
  (interactive "DDirectory: ")
  (let* ((lst
          (with-temp-buffer
            (apply #'call-process "du" nil t nil
                   (list "-h" (expand-file-name directory)))
            (split-string (buffer-string) "\n" t)))
         (result (mapconcat 'identity
                            (reverse (split-string (car (last lst))
                                                   " \\|\t")) " => ")))
    (if (called-interactively-p 'interactive) 
        (message "%s" result) result)))

;; Euro million
;;;###autoload
(defun euro-million ()
  (interactive)
  (let* ((star-num #'(lambda (limit)
                       ;; Get a random number between 1 to 12.
                       (let ((n 0))
                         (while (= n 0) (setq n (random limit)))
                         n)))
         (get-stars #'(lambda ()
                        ;; Return a list of 2 differents numbers from 1 to 12.
                        (let* ((str1 (number-to-string (funcall star-num 12)))
                               (str2 (let ((n (number-to-string (funcall star-num 12))))
                                       (while (string= n str1)
                                         (setq n (number-to-string (funcall star-num 12))))
                                       n)))
                          (list str1 str2))))      
         (result #'(lambda ()
                     ;; Collect random numbers without  dups.
                     (cl-loop repeat 5
                              for r = (funcall star-num 51)
                              if (not (member r L))
                              collect r into L
                              else
                              collect (let ((n (funcall star-num 51)))
                                        (while (memq n L)
                                          (setq n (funcall star-num 51)))
                                        n) into L
                                        finally return L)))
         (inhibit-read-only t))
    (with-current-buffer (get-buffer-create "*Euro million*")
      (erase-buffer)
      (insert "Grille aléatoire pour l'Euro Million\n\n")
      (cl-loop with ls = (cl-loop repeat 5 collect (funcall result))  
               for i in ls do
               (progn
                 (insert (mapconcat #'(lambda (x)
                                        (let ((elm (number-to-string x)))
                                          (if (= (length elm) 1) (concat elm " ") elm)))
                                    i " "))
                 (insert " Stars: ")
                 (insert (mapconcat 'identity (funcall get-stars) " "))
                 (insert "\n"))
               finally do (progn (pop-to-buffer "*Euro million*")
                                 (special-mode))))))

;; Just an example to use `url-retrieve'
;;;###autoload
(defun tv/download-file-async (url &optional noheaders to)
  (let ((noheaders noheaders) (to to))
    (url-retrieve url #'(lambda (status)
                          (if (plist-get status :error)
                              (signal (car status) (cadr status))
                              (switch-to-buffer (current-buffer))
                              (let ((inhibit-read-only t))
                                (goto-char (point-min))
                                ;; remove headers
                                (when noheaders
                                  (save-excursion
                                    (re-search-forward "^$")
                                    (forward-line 1)
                                    (delete-region (point-min) (point))))
                                (when to
                                  (write-file to)
                                  (kill-buffer (current-buffer)))))))))

;; Tool to take all sexps matching regexps in buffer and bring
;; them at point. Useful to reorder defvar, defcustoms etc...
;;;###autoload
(defun tv/group-sexp-matching-regexp-at-point (arg regexp)
  "Take all sexps matching REGEXP and put them at point.
The sexps are searched after point, unless ARG.
In this case, sexps are searched before point."
  (interactive "P\nsRegexp: ")
  (let ((pos (point))
        (fun (if arg 're-search-backward 're-search-forward))
        (sep (and (y-or-n-p "Separate sexp with newline? ") "\n")))
    (cl-loop while (funcall fun regexp nil t)
             do (progn
                  (beginning-of-defun)
                  (let ((beg (point))
                        (end (save-excursion (end-of-defun) (point))))
                    (save-excursion
                      (forward-line -1)
                      (when (search-forward "###autoload" (point-at-eol) t)
                        (setq beg (point-at-bol))))
                    (kill-region beg end)
                    (delete-blank-lines))
                  (save-excursion
                    (goto-char pos)
                    (yank)
                    (insert (concat "\n" sep))
                    (setq pos (point))))
             finally do (goto-char pos))))

;; Check paren errors
;;;###autoload
(defun tv/check-paren-error ()
  (interactive)
  (let (pos-err)
    (save-excursion
      (goto-char (point-min))
      (catch 'error
        (condition-case err
            (forward-list 9999)
          (error
           (throw 'error
             (setq pos-err (cl-caddr err)))))))
    (if pos-err
        (message "Paren error found in sexp starting at %s"
                 (goto-char pos-err))
        (message "No paren error found"))))

;;; Generate strong passwords.
;;
(defun tv/shuffle-vector (vector)
  "Shuffle VECTOR."
  (cl-loop with len = (1- (length vector))
           while (>= len 0)
           for rand = (random (1+ len))
           for old = (aref vector rand)
           do (progn
                (aset vector rand (aref vector len))
                (aset vector len old)
                (setq len (1- len)))
           finally return vector))

;;;###autoload
(cl-defun genpasswd (&optional (limit 12))
  "Generate strong password of length LIMIT.
LIMIT should be a number divisible by 2, otherwise
the password will be of length (floor LIMIT)."
  (cl-loop with alph = ["a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k"
                        "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v"
                        "w" "x" "y" "z" "A" "B" "C" "D" "E" "F" "G"
                        "H" "I" "J" "K" "L" "M" "N" "O" "P" "Q" "R"
                        "S" "T" "U" "V" "W" "X" "Y" "Z" "#" "!" "$"
                        "&" "~" "-" "_" "@" "%" "*"]
           ;; Divide by 2 because collecting 2 list.
           for i from 1 to (floor (/ limit 2))
           for rand1 = (int-to-string (random 9))
           for alphaindex = (random (length alph))
           for rand2 = (aref (tv/shuffle-vector alph) alphaindex)
           ;; Collect a random number between O-9
           concat rand1 into ls
           ;; collect a random alpha between a-zA-Z.
           concat rand2 into ls
           finally return ls))

;;;###autoload
(defun tv/generate-passwd (arg)
  (interactive "p")
  (message "New pwd `%s' saved to kill ring"
           (kill-new (genpasswd (max 8 arg)))))

;;;###autoload
(defun tv/gen-socgen-passwd ()
  (interactive)
  (let ((code (mapconcat (lambda (x) (number-to-string x))
                         (cl-loop with randoms = nil
                                  while (not (= (length randoms) 6))
                                  for random = (random 9)
                                  unless (member random randoms)
                                  do (push random randoms)
                                  finally return randoms)
                         "")))
    (kill-new code)
    (message "`%s' copied to kill-ring" code)))

;;; Toggle split window vertically/horizontally
;;
(defvar helm-alive-p)
;;;###autoload
(defun tv/toggle-window-split ()
  (interactive)
  (unless helm-alive-p
    (if (= (length (window-list)) 2)
        (let ((buf (current-buffer))
              before-height) 
          (with-current-buffer buf
            (setq before-height (window-height))
            (delete-window)
            (set-window-buffer
             (select-window (if (= (window-height) before-height)
                                (split-window-vertically)
                              (split-window-horizontally)))
             buf)))
      (user-error "Can toggle split only with two windows"))))
(global-set-key (kbd "C-x C-'") 'tv/toggle-window-split)

;;; Rotate windows
;;
;;
;;;###autoload
(defun tv/rotate-windows ()
  (interactive)
  (require 'iterator)
  (cl-assert (> (length (window-list)) 1)
          nil "Error: Can't rotate with a single window")
  (unless helm-alive-p
    (cl-loop with wlist1 = (iterator:circular (window-list))
             with wlist2 = (iterator:circular (cdr (window-list))) 
             with len = (length (window-list))
             for count from 1
             for w1 = (iterator:next wlist1)
             for b1 = (window-buffer w1)
             for s1 = (window-start w1)
             for w2 = (iterator:next wlist2)
             for b2 = (window-buffer w2)
             for s2 = (window-start w2)
             while (< count len)
             do (progn (set-window-buffer w1 b2)
                       (set-window-start w1 s2)
                       (set-window-buffer w2 b1)
                       (set-window-start w2 s1)))))
(global-set-key (kbd "C-c -") 'tv/rotate-windows)

;;;###autoload
(defun tv/delete-duplicate-lines (beg end &optional arg)
  "Delete duplicate lines in region omiting new lines.
With a prefix arg remove new lines."
  (interactive "r\nP")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (let ((lines (helm-fast-remove-dups
                    (split-string (buffer-string) "\n" arg)
                    :test 'equal)))
        (delete-region (point-min) (point-max))
        (cl-loop for l in lines do (insert (concat l "\n")))))))

;;;###autoload
(defun tv/break-long-string-list-at-point (arg)
  (interactive "p")
  (when (and (looking-at "(")
             (> (point-at-eol) (+ (point) 50)))
    (save-excursion
      (while (and (re-search-forward "\"[^\"]*\"" nil t arg)
                  (not (looking-at ")")))
        (newline-and-indent)))))

;; Stollen somewhere.
;;;###autoload
(defun tv/generate-kbd (key)
  (interactive "kGenerate and kill `kbd' form for key: ")
  (kill-new (message "(kbd \"%s\")" (help-key-description key nil)))
  (message nil))

;;;###autoload
(defun tv/insert-key-name-at-point (key)
  (interactive "kGenerate and kill `kbd' form for key: ")
  (insert (format "(kbd \"%s\")" (help-key-description key nil)))
  (message nil))

;; some tar fn to use in eshell aliases.
;;;###autoload
(defun tar-gunzip (file)
  (shell-command
   (format "tar czvf $(basename %s).tar.gz $(basename %s)"
           file file)))

;;;###autoload
(defun tar-bunzip (file)
  (shell-command
   (format "tar cjvf $(basename %s).tar.bz $(basename %s)"
           file file)))

;;;###autoload
(defun tar-xz (file)
  (shell-command
   (format "tar cJvf $(basename %s).tar.xz $(basename %s)"
           file file)))

;;;###autoload
(defun tv/resize-img (input-file percent-size output-file)
  (interactive (let* ((in (read-file-name "Input file: " "~/Images"))
                      (pcge (read-string "Resize percentage: " "25"))
                      (of (read-file-name "Output file: " nil in nil in)))
                 (list in pcge of)))
  (shell-command (format "convert %s -resize %s%% %s"
                         input-file
                         percent-size
                         output-file)))

;;;###autoload
(defun tv/split-freeboxvpn-config (file dir)
  (interactive (list (helm-read-file-name
                      "ConfigFile: "
                      :initial-input "~/Téléchargements/"
                      :must-match t
                      :preselect ".*\\.ovpn")
                     (read-directory-name
                      "SplitToDirectory: " "~/openvpn/")))
  (unless (file-directory-p dir) (mkdir dir t))
  (let ((ca (expand-file-name "ca.crt" dir))
        (client (expand-file-name "client.crt" dir))
        (key (expand-file-name "client.key" dir))
        (newfile (expand-file-name (helm-basename file) dir))
        ca-crt cli-crt key-key cfg beg end)
    (with-current-buffer (find-file-noselect file)
      (goto-char (point-min))
      (when (re-search-forward "^<ca>" nil t)
        (setq cfg (buffer-substring-no-properties
                   (point-min) (point-at-bol)))
        (forward-line 1) (setq beg (point))
        (re-search-forward "^</ca>" nil t)
        (forward-line 0) (setq end (point))
        (setq ca-crt (buffer-substring-no-properties beg end)))
      (when (re-search-forward "^<cert>" nil t)
        (forward-line 1) (setq beg (point))
        (re-search-forward "^</cert>" nil t)
        (forward-line 0) (setq end (point))
        (setq cli-crt (buffer-substring-no-properties beg end)))
      (when (re-search-forward "^<key>" nil t)
        (forward-line 1) (setq beg (point))
        (re-search-forward "^</key>" nil t)
        (forward-line 0) (setq end (point))
        (setq key-key (buffer-substring-no-properties beg end)))
      (kill-buffer))
    (cl-loop for f in `(,ca ,client ,key)
             for c in `(,ca-crt ,cli-crt ,key-key)
             do
             (with-current-buffer (find-file-noselect f)
               (erase-buffer)
               (insert c)
               (save-buffer)
               (kill-buffer)))
    (with-current-buffer (find-file-noselect newfile)
      (erase-buffer)
      (insert cfg
              "ca ca.crt\n"
              "cert client.crt\n"
              "key client.key\n")
      (save-buffer)
      (kill-buffer))))


(cl-defun tv/get-passwd-from-auth-sources (host &key user port)
  "Retrieve a password for auth-info file.
Arg `host' is machine in auth-info file."
  (let* ((token (auth-source-search :host host :port port :user user))
         (secret (plist-get (car token) :secret)))
    (if (functionp secret) (funcall secret) secret)))

;; Avoid typing password for sudo in eshell
(defun tv/advice--eshell-send-invisible ()
  (interactive) ; Don't pass str as argument, to avoid snooping via C-x ESC ESC
  (let ((str (read-passwd
	      (format "%s Password: "
		      (process-name (eshell-interactive-process)))
              nil (tv/get-passwd-from-auth-sources
                   "default" :user "root" :port "sudo"))))
    (if (stringp str)
	(process-send-string (eshell-interactive-process)
			     (concat str "\n"))
      (message "Warning: text will be echoed"))))
(advice-add 'eshell-send-invisible :override #'tv/advice--eshell-send-invisible)

(defvar tv/freesms-default-url
  "https://smsapi.free-mobile.fr/sendmsg?user=%s&pass=%s&msg=%s")
;;;###autoload
(defun tv/freesms-notify (login msg)
  (interactive (list
                (completing-read "User: " '("thierry" "rachel"))
                (read-string "Message: ")))
  (setq msg (url-hexify-string msg))
  (let* ((host  (format "freesms%s" login))
         (user (plist-get (car (auth-source-search :host host)) :user))
         (pwd   (tv/get-passwd-from-auth-sources host :user user)))
    (with-current-buffer (url-retrieve-synchronously
                          (format tv/freesms-default-url user pwd msg))
      (goto-char (point-min))
      (let* ((rcode (nth 1 (split-string (buffer-substring-no-properties
                                          (point-at-bol) (point-at-eol)))))
             (rcode-msg
              (cond ((string= "200" rcode) "Le SMS a été envoyé sur votre mobile.")
                    ((string= "400" rcode) "Un des paramètres obligatoires est manquant.")
                    ((string= "402" rcode) "Trop de SMS ont été envoyés en trop peu de temps.")
                    ((string= "403" rcode) "Le service n'est pas activé sur l'espace abonné, ou login / clé incorrect.")
                    ((string= "500" rcode) "Erreur côté serveur. Veuillez réessayer ultérieurement.")
                    (t "Unknow error"))))
        (if (string= rcode-msg "200")
            (message rcode-msg)
            (error rcode-msg))))))

;;; Scroll functions
(defun tv/scroll-down ()
  (interactive)
  (scroll-down -1))

(defun tv/scroll-up ()
  (interactive)
  (scroll-down 1))

(defun tv/scroll-other-down ()
  (interactive)
  (scroll-other-window 1))

(defun tv/scroll-other-up ()
  (interactive)
  (scroll-other-window -1))

(defun tv/update-helm-only-symbol (dir)
  (cl-loop for f in (directory-files dir t "\\.el\\'")
           do (with-current-buffer (find-file-noselect f)
                (save-excursion
                  (goto-char (point-min))
                  (let (fun)
                    (while (re-search-forward "(with-helm-alive-p" nil t)
                      (when (setq fun (which-function))
                        (end-of-defun)
                        (unless (looking-at "(put")
                          (insert (format "(put '%s 'helm-only t)\n" fun))))))))))

(defun tv/thing-at-point-number ()
  (save-excursion
    (when (re-search-forward "[0-9]\\{1,6\\}" (min (+ (point) 6) (point-at-eol)) t)
      (string-to-number (match-string-no-properties 0)))))

(defun tv/find-or-kill-gnu-bug-number (bug-number arg)
  "Browse url corresponding to emacs gnu bug number or kill it."
  (interactive (list (read-number "Bug number: " (tv/thing-at-point-number))
                     current-prefix-arg))
  (let ((url (format "http://debbugs.gnu.org/cgi/bugreport.cgi?bug=%s" bug-number)))
    (if arg
        (progn
          (kill-new url)
          (message "Bug `#%d' url's copied to kill-ring" bug-number))
        (browse-url url))))

(defun tv/find-or-kill-helm-bug-number (bug-number arg)
  "Browse url corresponding to helm bug number or kill it."
  (interactive (list (read-number "Bug number: " (tv/thing-at-point-number))
                     current-prefix-arg))
  (let ((url (format "https://github.com/emacs-helm/helm/issues/%s" bug-number)))
    (if arg
        (progn
          (kill-new url)
          (message "Bug `#%d' url's copied to kill-ring" bug-number))
        (browse-url url))))

;;;###autoload
(defun tv/restore-scratch-buffer ()
  (unless (buffer-file-name (get-buffer "*scratch*"))
    (and (get-buffer "*scratch*") (kill-buffer "*scratch*")))
  (with-current-buffer (find-file-noselect "~/.emacs.d/save-scratch.el")
    (rename-buffer "*scratch*")
    (lisp-interaction-mode)
    (setq lexical-binding t)
    (use-local-map lisp-interaction-mode-map))
  (when (or (eq (point-min) (point-max))
            ;; For some reason the scratch buffer have not a zero size.
            (<= (buffer-size) 2))
    (insert ";;; -*- coding: utf-8; mode: lisp-interaction; lexical-binding: t -*-\n;;\n;; SCRATCH BUFFER\n;; ==============\n\n")))

;;; wttr.in weather report
;;
(defvar wttr-weather-history nil)
(defvar wttr-weather-default-location "Le Beausset")
(defvar wttr-weather-last-location nil)
;;;###autoload
(defun wttr-weather (place)
  "Weather forecast with wttr.in.
With a prefix arg refresh buffer if some.
See <https://github.com/chubin/wttr.in>."
  (interactive (list (read-string "Place: " nil 'wttr-weather-history
                                  wttr-weather-default-location)))
  (require 'helm-lib)
  (let ((buf (get-buffer-create (format "*wttr.in %s*" place))))
    (switch-to-buffer buf)
    (when current-prefix-arg
      (set (make-local-variable 'wttr-weather-last-location) nil))
    (unless wttr-weather-last-location
      (wttr-weather-update place)
      (wttr-weather-mode)
      (set (make-local-variable 'wttr-weather-last-location) place))))

(defun wttr-weather-update (place)
  (let* ((inhibit-read-only t)
         ansi
         (data
          (with-temp-buffer
            (call-process
             "curl" nil '(t t) nil
             "-s" (format "fr.wttr.in/~%s?m" (shell-quote-argument place)))
            (goto-char (point-min))
            (while (re-search-forward "38;5;\\([0-9]+\\)m" nil t)
              ;; If we have ansi sequences, that's mean we had weather
              ;; output, otherwise we have a simple message notifying
              ;; weather report is not available.
              (setq ansi t)
              ;; Need a 256 color ansi library, emacs supports only basic
              ;; ansi colors as now, so replace all 38;5 foreground
              ;; specs by simple ansi sequences.
              (replace-match (pcase (match-string 1)
                               ("154" "32")
                               ("190" "31")
                               ("118" "32")
                               ("208" "37")
                               ("202" "34")
                               ("214" "35")
                               ("220" "36")
                               ("226" "33")
                               (r     r))
                             t t nil 1))
            (helm--ansi-color-apply (buffer-string)))))
    (erase-buffer)
    (save-excursion
      (insert data)
      (forward-line -1)
      (when (and ansi ; Keep notification when no weather report.
                 (re-search-backward "^$" nil t))
        (delete-region (point) (point-max))))
    (while (re-search-forward "\\s\\" (point-at-eol) t) (replace-match ""))
    (goto-char (point-at-eol))
    (insert (format-time-string " le %d/%m/%Y à %H:%M:%S"))))

(defun wttr-weather-revert-fn (_ignore-auto _no_confirm)
  (wttr-weather-update wttr-weather-last-location))

(define-derived-mode wttr-weather-mode special-mode "wttr"
  (make-local-variable 'wttr-weather-last-location)
  (set (make-local-variable 'revert-buffer-function) 'wttr-weather-revert-fn))

(provide 'tv-utils)

;; Local Variables:
;; byte-compile-warnings: (not cl-functions obsolete)
;; End:

;;; tv-utils.el ends here
