;; * navi-mode.el --- major-mode for easy buffer-navigation
;; ** Copyright

;; Copyright (C) 2013 Thorsten Jolitz

;; Maintainer: Thorsten Jolitz <tjolitz AT gmail DOT com>
;; Version: 0.9
;; Keywords: occur

;; ** Licence

;; This file is not part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;; ** Commentary

;; This file implements extensions for occur-mode.
;;
;; ** Installation
;;
;; ** Usage
;;
;; ** Compatibility:

;; * Requires

(require 'outshine)

;; * Mode Definitions

(define-derived-mode navi-mode
  occur-mode "Navi"
  "Major mode for easy buffer-navigation.
In this mode (derived from `occur-mode') you can easily navigate
in an associated original-buffer via one-key commands in the
navi-buffer. You can alter the displayed document structure in
the navi-buffer by sending one-key commands that execute
predefined occur searches in the original buffer. `navi-mode' is
especially useful in buffers with outline structure, e.g. buffers
with `outline-minor-mode' activated and `outshine' extensions
loaded.
\\{navi-mode-map}"
  (set (make-local-variable 'revert-buffer-function) 'navi-revert-function)
  (setq case-fold-search nil))
 
;; * Variables
;; ** Consts
;; ** Vars

(defvar navi-mode-version 0.9
  "Version number of `navi-mode.el'")

(defvar navi "navi"
  "Symbol that holds pairs of buffer-marker names in its plist.
Keys are buffernames as keyword-symbols, values are markers that
point to original-buffers")

(defvar navi-regexp-quoted-line-at-point ""
  "Regexp that matches the line at point in navi-buffer.")

;; ** Hooks
;; ** Fonts
;; ** Customs
;; *** Custom Groups 

(defgroup navi-mode nil
  "Library for outline navigation and Org-mode editing in Lisp buffers."
  :prefix "navi-"
  :group 'lisp 'outlines)

;; *** Custom Vars

(defcustom navi-var-keywords nil
  "."
  :group 'navi-mode
  :type 'boolean)


(defcustom navi-fp-keywords nil
  "."
  :group 'navi-mode
  :type 'boolean)


(defcustom navi-oop-keywords nil
  "."
  :group 'navi-mode
  :type 'boolean)


;; * Defuns
;; ** Functions

;; (defun navi-mode-hook-function ()
;;   "Function to be run after `navi-mode' is loaded."
;;   (add-to-list 'occur-hook 'occur-rename-buffer))

(defun navi-regexp-quote-line-at-point ()
  "Store a quoted regexp for line at point.
Leading and trailing whitespace is deleted."
  (setq navi-regexp-quoted-line-at-point
   (regexp-quote
    (outshine-chomp
     (substring-no-properties
     (buffer-string) (point-at-bol) (point-at-eol)))))
  (format "%s" navi-regexp-quoted-line-at-point))

(defun navi-search-less-or-equal-line-number (&optional num)
  "Search closest result-line to given line-number.
This function searches a result-line in a navi-buffer with
line-number less-or-equal to line-number of
`navi-regexp-quoted-line-at-point' or NUM. Its not about
line-numbers in the navi-buffer, but about the line-numbers in
the original-buffer shown in the occur-search results."
  (let* ((line-num-str (or
                        (and
                         num (integer-or-marker-p num) (>= num 1)
                         (int-to-string num))
                        (car
                         (split-string
                          navi-regexp-quoted-line-at-point
                          ":" 'OMIT-NULLS))))
         (line-num (string-to-int line-num-str))
         (match-point))
    (save-excursion
      (goto-char (point-min))
      (while (and (>= line-num 1)
                  (not
                   (setq match-point
                         (re-search-forward
                          (concat "^[[:space:]]*"
                                  line-num-str
                                  ":") 
                          nil 'NO-ERROR))))
        (goto-char (point-min))
        (setq line-num (1- line-num))
        (setq line-num-str (int-to-string line-num)))
      (goto-char match-point)
      (forward-line)
      (occur-prev)
      (point))))

(defun navi-goto-occurrence-other-window ()
  "Moves navi-buffer marker to point before switching buffers."
  (interactive)
  (move-marker
   (car (navi-get-twin-buffer-markers)) (point))
  (occur-mode-goto-occurrence-other-window))

(defun navi-make-buffer-key (&optional buf)
  "Return the (current) buffer-name or string BUF as interned keyword-symbol"
  (let ((buf-name
         (file-name-sans-extension
          (car (split-string (or buf (buffer-name)) "[*]" 'OMIT-NULLS)))))
  (intern (concat ":" buf-name))))

(defun navi-make-marker-name (&optional buf)
  "Return marker-name by expansion of (current) buffer-name or string BUF."
  (let ((buf-name
         (file-name-sans-extension
          (car (split-string (or buf (buffer-name)) "[*]" 'OMIT-NULLS)))))
  (concat buf-name "-marker")))

(defun navi-get-twin-buffer-markers ()
  "Return list with two markers pointing to buffer-twins or nil.
CAR of the return-list is always the marker pointing to
 current-buffer, CDR the marker pointing to its twin-buffer."
  (let* ((curr-buf-split
          (split-string (buffer-name) "[*:]" 'OMIT-NULLS))
         (is-navi-buffer-p
          (string-equal (car curr-buf-split) "Navi"))
         (twin-of-navi
          (and is-navi-buffer-p
               (get 'navi (navi-make-buffer-key (cadr curr-buf-split)))))
         (self-navi
          (and is-navi-buffer-p
               (get 'navi (navi-make-buffer-key
                           (concat
                            (car curr-buf-split)
                            ":"
                            (cadr curr-buf-split))))))
         (twin-of-orig
          (unless is-navi-buffer-p
            (get 'navi (navi-make-buffer-key
                        (concat "Navi:" (car curr-buf-split))))))
         (self-orig
          (unless is-navi-buffer-p
            (get 'navi (navi-make-buffer-key (car curr-buf-split))))))
    (if is-navi-buffer-p
        (and self-navi twin-of-navi
             (list self-navi twin-of-navi))
      (and self-orig twin-of-orig
           (list self-orig twin-of-orig)))))


;; modified `occur-rename-buffer' from `replace.el'
(defun navi-rename-buffer (&optional unique-p)
  "Rename the current *Occur* buffer to *Navi: original-buffer-name*.
Here `original-buffer-name' is the buffer name where Occur was
originally run. When given the prefix argument, the renaming will
not clobber the existing buffer(s) of that name, but use
`generate-new-buffer-name' instead. You can add this to
`occur-hook' if you always want a separate *Occur* buffer for
each buffer where you invoke `occur'."
  (let ((orig-buffer-name ""))
    (with-current-buffer
        (if (eq major-mode 'occur-mode) (current-buffer) (get-buffer "*Occur*"))
      (setq orig-buffer-name
            (mapconcat
             #'buffer-name
             (car (cddr occur-revert-arguments)) "/"))
      (rename-buffer (concat "*Navi:" orig-buffer-name "*") unique-p)
      ;; make marker for this navi-buffer
      ;; and store it in `navi''s plist
      (put 'navi
           (navi-make-buffer-key)
           (set
            (intern
             (navi-make-marker-name
              (cadr (split-string (buffer-name) "[*:]" 'OMIT-NULLS))))
            (point-marker))))))

(defun navi-calc-headline-regexp (level &optional NO-PARENT-LEVELS)
  "Calculate regexp to show headers of original-buffer.
Regexp should result in an occur-search showing up to
outline-level LEVEL headlines in navi-buffer. If NO-PARENT-LEVELS
in non-nil, only headers of level LEVEL are shown."
  (let* ((orig-buf (marker-buffer
                    (cadr (navi-get-twin-buffer-markers))))
         (outline-base-string
          (with-current-buffer orig-buf
            (outshine-transform-normalized-outline-regexp-base-to-string)))
         (rgxp-string
          (regexp-quote
           (outshine-chomp
            (format
             "%s" (car (rassoc 1 (with-current-buffer orig-buf
                                   outline-promotion-headings)))))))
         (rgxp (if (not (and level
                             (integer-or-marker-p level)
                             (>= level 1)
                             (<= level 8)))
                   (error "Level must be an integer between 1 and 8")
                 (if NO-PARENT-LEVELS
                     (regexp-quote
                      (format
                       "%s"
                       (car
                        (rassoc level
                                (with-current-buffer orig-buf
                                  outline-promotion-headings)))))
                   (concat
                    (dotimes (i (1- level) rgxp-string)
                      (setq rgxp-string
                            (concat rgxp-string
                                    (regexp-quote
                                     outline-base-string)
                                    "?")))
                    " ")))))
    rgxp))

(defun navi-clean-up ()
  "Clean up `navi' plist and left-over markers after killing navi-buffer."
  (setq navi-revert-arguments nil)
  (setq navi-regexp-quoted-line-at-point nil))


;; (add-to-list 'occur-hook 'navi-rename-buffer)

;; ** Commands

;; Convenience function copied from whom ??
(defun isearch-occur ()
  "Invoke `occur' from within isearch."
  (interactive)
  (let ((case-fold-search isearch-case-fold-search))
    (occur (if isearch-regexp isearch-string (regexp-quote isearch-string)))))

(defun navi-search-and-switch ()
  "Call `occur' and immediatley switch to `*Navi:original-buffer-name*' buffer"
  (interactive)
  (let ((1st-level-headers
         (regexp-quote
          (outshine-calc-outline-string-at-level 1))))
    (put 'navi (navi-make-buffer-key (buffer-name))
         (set (intern (navi-make-marker-name)) (point-marker)))
    (occur 1st-level-headers)
    (navi-rename-buffer)
    (navi-switch-to-twin-buffer)
    (navi-mode)
    (occur-next)
    (move-marker
     (car (navi-get-twin-buffer-markers)) (point))
    (navi-regexp-quote-line-at-point)))

;; (defun navi-quit-and-switch ()
;;   "Quit navi-buffer and immediatley switch back to original-buffer"
;;   (interactive)
;;   (quit-window)
;;   (switch-to-buffer
;;    (marker-buffer original-buffer-marker))
;;   (goto-char
;;    (marker-position original-buffer-marker)) ; necessary?
;;   (set-marker navi-buffer-marker nil)
;;   (set-marker original-buffer-marker nil))

(defun navi-switch-to-twin-buffer ()
  "Switch to associated twin-buffer of current buffer or do nothing."
  (interactive)
  (let* ((marker-list (navi-get-twin-buffer-markers))
         (self-marker (car marker-list))
         (twin-marker (cadr marker-list)))
    (and marker-list
         (move-marker self-marker (point) (marker-buffer self-marker))
         (switch-to-buffer-other-window (marker-buffer twin-marker))
         (goto-char (marker-position twin-marker))
         (and (eq major-mode 'navi-mode)
              (navi-revert-function)))))

;; adapted from 'replace.el'
(defun navi-revert-function (&optional regexp)
  "Handle `revert-buffer' for navi-buffers."
  (interactive)
  (let ((navi-revert-arguments
         (if regexp
            (append
             (list regexp) (cdr occur-revert-arguments))
           occur-revert-arguments)))
    (navi-regexp-quote-line-at-point)
    (apply 'occur-1 (append navi-revert-arguments (list (buffer-name))))
    (navi-mode)
    (goto-char 
      (navi-search-less-or-equal-line-number))))

(defun navi-show-headers-level-1 (&optional args)
  "Show headers (up-to) level 1."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 1 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 1))))

(defun navi-show-headers-level-2 (&optional args)
  "Show headers (up-to) level 2."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 2 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 2))))

(defun navi-show-headers-level-3 (&optional args)
  "Show headers (up-to) level 3."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 3 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 3))))

(defun navi-show-headers-level-4 (&optional args)
  "Show headers (up-to) level 4."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 4 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 4))))

(defun navi-show-headers-level-5 (&optional args)
  "Show headers (up-to) level 5."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 5 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 5))))

(defun navi-show-headers-level-6 (&optional args)
  "Show headers (up-to) level 6."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 6 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 6))))

(defun navi-show-headers-level-7 (&optional args)
  "Show headers (up-to) level 7."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 7 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 7))))

(defun navi-show-headers-level-8 (&optional args)
  "Show headers (up-to) level 8."
  (interactive "P")
  (if args
      (navi-revert-function
       (navi-calc-headline-regexp 8 'NO-PARENT-LEVELS))
    (navi-revert-function
     (navi-calc-headline-regexp 8))))

;; TODO args from [1-8]: show headline-levels too
(defun navi-show-oop-keywords (&optional args)
  "Show keywords listed in `navi-oop-keywords'."
  (interactive "P"))

(defun navi-show-fp-keywords (&optional args)
  "Show keywords listed in `navi-oop-keywords'."
  (interactive "P"))

(defun navi-show-var-keywords (&optional args)
  "Show keywords listed in `navi-oop-keywords'."
  (interactive "P"))


;; * Keybindings

;; example keybinding
;; (define-key navi-mode-map
;;  [down-mouse-3] 'do-hyper-link)


;; Occur mode: new/better keybindings
(global-set-key (kbd "M-s n") 'navi-search-and-switch)
(global-set-key (kbd "M-s s") 'navi-switch-to-twin-buffer)
(global-set-key (kbd "M-s M-s") 'navi-switch-to-twin-buffer)
(define-key navi-mode-map (kbd "s") 'navi-switch-to-twin-buffer)
(define-key navi-mode-map (kbd "d") 'occur-mode-display-occurrence)
(define-key navi-mode-map (kbd "o") 'navi-goto-occurrence-other-window)
(define-key navi-mode-map (kbd "n") 'occur-next)
(define-key navi-mode-map (kbd "p") 'occur-prev)
(define-key navi-mode-map (kbd "r") 'navi-revert-function)
(define-key navi-mode-map (kbd "q") 'navi-quit-and-switch)
(define-key navi-mode-map (kbd "1") 'navi-show-headers-level-1)
(define-key navi-mode-map (kbd "2") 'navi-show-headers-level-2)
(define-key navi-mode-map (kbd "3") 'navi-show-headers-level-3)
(define-key navi-mode-map (kbd "4") 'navi-show-headers-level-4)
(define-key navi-mode-map (kbd "5") 'navi-show-headers-level-5)
(define-key navi-mode-map (kbd "6") 'navi-show-headers-level-6)
(define-key navi-mode-map (kbd "7") 'navi-show-headers-level-7)
(define-key navi-mode-map (kbd "8") 'navi-show-headers-level-8)
(define-key isearch-mode-map (kbd "M-s i") 'isearch-occur)

;; * Run Hooks and Provide

(provide 'navi-mode)

;; navi-mode.el ends here

