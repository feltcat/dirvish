;;; dirvish-helpers.el --- Helper functions for Dirvish -*- lexical-binding: t -*-

;; This file is NOT part of GNU Emacs.

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Helper functions for dirvish.

;;; Code:

(require 'dirvish-core)
(require 'dirvish-options)
(require 'dired-x)

(defmacro dirvish-here (&optional path &rest keywords)
  "Open Dirvish with PATH and KEYWORDS.

PATH defaults to variable `buffer-file-name'.
KEYWORDS are slot key-values for `dirvish-new'."
  (declare (indent defun))
  `(let* ((f (or ,path buffer-file-name))
          (dir (expand-file-name (if f (file-name-directory f) default-directory))))
     (dirvish-activate (dirvish-new ,@keywords))
     (dirvish-find-file dir)))

(defmacro dirvish-repeat (func delay interval &rest args)
  "Execute FUNC with ARGS in every INTERVAL after DELAY."
  (let ((timer (intern (format "%s-timer" func))))
    `(progn
       (defvar ,timer nil)
       (add-to-list 'dirvish-repeat-timers ',timer)
       (setq ,timer (run-with-timer ,delay ,interval ',func ,@args)))))

(defmacro dirvish-debounce (label &rest body)
  "Debouncing the execution of BODY.

The BODY runs after the idle time `dirvish-debouncing-delay'.
Multiple calls under the same LABEL are ignored."
  (let* ((timer (intern (format "dirvish-%s-debouncing-timer" label)))
         (do-once `(lambda () (unwind-protect ,@body (setq ,timer nil)))))
    `(progn
       (defvar ,timer nil)
       (unless (timerp ,timer)
         (setq ,timer (run-with-idle-timer dirvish-debouncing-delay nil ,do-once))))))

(defun dirvish-setup-dired-buffer (&rest _)
  "Setup Dired buffer for dirvish.
This function removes the header line in a Dired buffer."
  (save-excursion
    (let ((o (make-overlay
              (point-min)
              (progn (goto-char (point-min)) (forward-line 1) (point)))))
      (overlay-put o 'invisible t))))

(defun dirvish--shell-to-string (program &rest args)
  "Execute PROGRAM with arguments ARGS and return output string.

If program returns non zero exit code return nil."
  (let* ((exit-code nil)
         (output
          (with-output-to-string
            (with-current-buffer standard-output
              (setq exit-code (apply #'process-file program nil t nil args))))))
    (when (eq exit-code 0) output)))

(defun dirvish--display-buffer (buffer alist)
  "Try displaying BUFFER at one side of the selected frame.

 This splits the window at the designated side of the
 frame.  ALIST is window arguments for the new-window, it has the
 same format with `display-buffer-alist'."
  (let* ((side (cdr (assq 'side alist)))
         (window-configuration-change-hook nil)
         (width (or (cdr (assq 'window-width alist)) 0.5))
         (height (cdr (assq 'window-height alist)))
         (size (or height (ceiling (* (frame-width) width))))
         (split-width-threshold 0)
         (mode-line-format nil)
         (new-window (split-window-no-error nil size side)))
    (window--display-buffer buffer new-window 'window alist)))

(defun dirvish--enlarge (&rest _)
  "Kill all dirvish parent windows except the root one."
  (when (dirvish-curr)
    (cl-dolist (win (dv-dired-windows (dirvish-curr)))
      (and (not (eq win (dv-root-window (dirvish-curr))))
           (window-live-p win)
           (delete-window win)))))

(defun dirvish--get-parent (path)
  "Get parent directory of PATH."
  (file-name-directory (directory-file-name (expand-file-name path))))

(defun dirvish--get-filesize (fileset)
  "Determine file size of provided list of files in FILESET."
  (unless (executable-find "du") (user-error "`du' executable not found"))
  (with-temp-buffer
    (apply #'call-process "du" nil t nil "-sch" fileset)
    (format "%s" (progn (re-search-backward "\\(^[0-9.,]+[a-zA-Z]*\\).*total$")
                        (match-string 1)))))

(defun dirvish--get-trash-dir ()
  "Get trash directory for current disk."
  (cl-dolist (dir dirvish-trash-dir-alist)
    (when (string-prefix-p (car dir) (dired-current-directory))
      (cl-return (concat (car dir) (cdr dir))))))

(defun dirvish--append-metadata (metadata completions)
  "Append METADATA for minibuffer COMPLETIONS."
  (let ((entry (if (functionp metadata)
                   `(metadata (annotation-function . ,metadata))
                 `(metadata (category . ,metadata)))))
    (lambda (string pred action)
      (if (eq action 'metadata)
          entry
        (complete-with-action action completions string pred)))))

(provide 'dirvish-helpers)
;;; dirvish-helpers.el ends here
