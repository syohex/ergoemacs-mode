;;; ergoemacs-shortcuts.el --- Ergoemacs shortcuts interface
;;
;; Filename: ergoemacs-shortcuts.el
;; Description:
;; Author: Matthew L. Fidler
;; Maintainer: 
;; Created: Sat Sep 28 20:10:56 2013 (-0500)
;; Version: 
;; Last-Updated: 
;;           By: 
;;     Update #: 0
;; URL: 
;; Doc URL: 
;; Keywords: 
;; Compatibility: 
;; 
;; Features that might be required by this library:
;;
;;   None
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Commentary: 
;; 
;;
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Change Log:
;; 
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Code:
(defmacro ergoemacs-setup-keys-for-keymap (keymap)
  "Setups ergoemacs keys for a specific keymap"
  `(condition-case err
       (let ((no-ergoemacs-advice t)
             (case-fold-search t)
             key
             trans-key input-keys
             cmd cmd-tmp)
         (ergoemacs-debug-heading ,(format "Setup keys for %s" (symbol-name keymap)))
         (if (eq ',keymap 'ergoemacs-keymap)
             (setq ,keymap (make-sparse-keymap))
           (ergoemacs-debug "Theme: %s" ergoemacs-theme))
         ;; Fixed layout keys
         (ergoemacs-debug-heading "Setup Fixed Keys")
         (mapc
          (lambda(x)
            (when (and (eq 'string (type-of (nth 0 x))))
              (setq trans-key (ergoemacs-get-kbd-translation (nth 0 x)))              
              (if ergoemacs-change-fixed-layout-to-variable-layout
                  (progn ;; Change to the fixed keyboard layout.
                    (setq key (ergoemacs-kbd trans-key)))
                (condition-case err
                    (setq key (read-kbd-macro trans-key t))
                  (error
                   (setq key (read-kbd-macro
                              (encode-coding-string
                               trans-key
                               locale-coding-system) t)))))
              (when (eq ',keymap 'ergoemacs-keymap)
                (ergoemacs-debug "Fixed %s: %s -> %s %s (%s)"
                                 (nth 0 x) trans-key cmd
                                 key (key-description key))
                (when (string-match "^\\([^ ]+\\) " (nth 0 x))
                  (add-to-list 'input-keys (match-string 1 (nth 0 x)))))
              (if (ergoemacs-global-changed-p trans-key)
                  (progn
                    (ergoemacs-debug "!!!Fixed %s has changed globally." trans-key)
                    (ergoemacs-define-key ,keymap key (lookup-key (current-global-map) key)))
                (setq cmd (nth 1 x))
                (when (not (ergoemacs-define-key ,keymap key cmd))
                  (ergoemacs-debug "Key %s->%s not setup." key cmd)))))
          (symbol-value (ergoemacs-get-fixed-layout)))
         (ergoemacs-debug-heading "Setup Variable Layout Keys")
         ;; Variable Layout Keys
         (mapc
          (lambda(x)
            (when (and (eq 'string (type-of (nth 0 x))))
              (setq trans-key
                    (ergoemacs-get-kbd-translation (nth 0 x)))
              (setq key (ergoemacs-kbd trans-key nil (nth 3 x)))
              (if (ergoemacs-global-changed-p trans-key t)
                  (progn
                    (ergoemacs-debug "!!!Variable %s (%s) has changed globally."
                                     trans-key (ergoemacs-kbd trans-key t (nth 3 x))))
                ;; Add M-O and M-o handling for globally defined M-O and
                ;; M-o.
                ;; Only works if ergoemacs-mode is on...
                (setq cmd (nth 1 x))
                (when cmd
                  (ergoemacs-define-key ,keymap key cmd)
                  (when (eq ',keymap 'ergoemacs-keymap)
                    (ergoemacs-debug "Variable: %s (%s) -> %s %s" trans-key (ergoemacs-kbd trans-key t (nth 3 x)) cmd key)
                    (when (string-match "^\\([^ ]+\\) " (ergoemacs-kbd trans-key t (nth 3 x)))
                      (add-to-list
                       'input-keys
                       (match-string 1 (ergoemacs-kbd trans-key t (nth 3 x))))))))))
          (symbol-value (ergoemacs-get-variable-layout)))
         (ergoemacs-debug-keymap ',keymap)
         (when input-keys
           (ergoemacs-debug-heading "Setup Read Input Layer")
           (setq ergoemacs-read-input-keymap (make-sparse-keymap))
           (mapc
            (lambda(key)
              (unless (member key ergoemacs-ignored-prefixes)
                (define-key ergoemacs-read-input-keymap
                  (read-kbd-macro key)
                  `(lambda()
                     (interactive)
                     (ergoemacs-read-key ,key 'normal)))))
            input-keys)
           (ergoemacs-debug-keymap 'ergoemacs-read-input-keymap)))
     (error
      (ergoemacs-debug "Error: %s" err)
      (ergoemacs-debug-flush))))

(defmacro ergoemacs-with-overrides (&rest body)
  "With the `ergoemacs-mode' mode overrides.
The global map is ignored, but major/minor modes keymaps are included."
  `(let (ergoemacs-mode
         ergoemacs-unbind-keys
         ergoemacs-shortcut-keys
         ergoemacs-modal
         ergoemacs-read-input-keys
         (old-global-map (current-global-map))
         (new-global-map (make-sparse-keymap)))
     (unwind-protect
         (progn
           (use-global-map new-global-map)
           ,@body)
       (use-global-map old-global-map))))

(defmacro ergoemacs-with-global (&rest body)
  "With global keymap, not ergoemacs keymaps."
  `(ergoemacs-without-emulation
    (let (ergoemacs-mode ergoemacs-unbind-keys)
      ,@body)))

(defmacro ergoemacs-with-major-and-minor-modes (&rest body)
  "Without global keymaps and ergoemacs keymaps."
  `(let ((old-global-map (current-global-map))
         (new-global-map (make-sparse-keymap)))
     (unwind-protect
         (progn
           (use-global-map new-global-map)
           (ergoemacs-with-global
            ,@body))
       (use-global-map old-global-map))))

(defmacro ergoemacs-without-emulation (&rest body)
  "Without keys defined at `ergoemacs-emulation-mode-map-alist'.

Also temporarily remove any changes ergoemacs-mode made to:
- `overriding-terminal-local-map'
- `overriding-local-map'

Will override any ergoemacs changes to the text properties by temporarily
installing the original keymap above the ergoemacs-mode installed keymap.
"
  `(let ((overriding-terminal-local-map overriding-terminal-local-map)
         (overriding-local-map overriding-local-map)
         lookup tmp-overlay override-text-map)
     ;; Remove most of ergoemacs-mode's key bindings
     (remove-hook 'emulation-mode-map-alists 'ergoemacs-emulation-mode-map-alist)
     (unwind-protect
         (progn
           ;; Remove ergoemacs-mode changes to
           ;; overriding-terminal-local-map.
           (when (and overriding-terminal-local-map
                      (eq saved-overriding-map t)
                      (or (eq (lookup-key
                           overriding-terminal-local-map [ergoemacs]) 'ignore)
                          (eq (lookup-key
                               overriding-terminal-local-map [ergoemacs-read]) 'ignore)))
             (setq hashkey (md5 (format "override-terminal-orig:%s" overriding-terminal-local-map)))
             (setq lookup (gethash hashkey ergoemacs-extract-map-hash))
             (when lookup
               (setq overriding-terminal-local-map lookup)))
           
           ;; Remove ergoemacs-mode changes to overriding-local-map
           (when (and overriding-local-map
                      (or (eq (lookup-key overriding-local-map [ergoemacs]) 'ignore)
                          (eq (lookup-key overriding-local-map [ergoemacs-read]) 'ignore)))
             (setq lookup (gethash (md5 (format "override-local-orig:%s" overriding-local-map)) ergoemacs-extract-map-hash))
             (when lookup
               (setq overriding-local-map lookup)))
           
           ;; Install override-text-map changes above anything already
           ;; installed.
           (setq override-text-map (get-char-property (point) 'keymap))
           (when (and (keymapp override-text-map)
                      (or (eq (lookup-key override-text-map [ergoemacs]) 'ignore)
                          (eq (lookup-key override-text-map [ergoemacs-read]) 'ignore)))
             (setq lookup (gethash (md5 (format "char-map-orig:%s" override-text-map)) ergoemacs-extract-map-hash))
             (when lookup
               (setq tmp-overlay (make-overlay (max (- (point) 1) (point-min))
                                               (min (+ (point) 1) (point-max))))
               (overlay-put tmp-overlay 'keymap lookup)
               (overlay-put tmp-overlay 'priority 536870911)))
           ,@body)
       (when tmp-overlay
         (delete-overlay tmp-overlay))
       (when ergoemacs-mode
         (add-hook 'emulation-mode-map-alists 'ergoemacs-emulation-mode-map-alist)))))

(defgroup ergoemacs-read nil
  "Options for ergoemacs-read-key."
  :group 'ergoemacs-mode)

(defcustom ergoemacs-translate-keys t
  "When translation is enabled, when a command is not defined
look for the command with or without modifiers."
  :type 'boolean
  :group 'ergoemacs-read)

(defcustom ergoemacs-translate-emacs-keys t
  "When key is undefined, translate to an emacish key.

For example in `org-mode' C-c C-n performs
`outline-next-visible-heading'.  A QWERTY `ergoemacs-mode' key
equivalent is <apps> f M-k.  When enabled, pressing this should also perfomr `outline-next-visible-heading'"
  :type 'boolean
  :group 'ergoemacs-read)

(defvar ergoemacs-first-variant nil
  "First variant of `ergoemacs-read' key.")
(defvar ergoemacs-describe-key nil)
(defun ergoemacs-describe-key ()
  "Ergoemacs replacement for `describe-key'
Uses `ergoemacs-read'"
  (interactive)
  (setq ergoemacs-describe-key t)
  (ergoemacs-read-key nil 'normal))

(defvar ergoemacs-single-command-keys nil)
(defvar ergoemacs-mark-active nil)

(defun ergoemacs-to-sequence (key)
  "Returns a key sequence from KEY.
This sequence is compatible with `listify-key-sequence'."
  (let (input)
    (cond
     ((not key)) ;; Not specified.
     ((eq (type-of key) 'vector) ;; Actual key sequence
      (setq input (listify-key-sequence key)))
     ((eq (type-of key) 'cons) ;; Listified key sequence
      (setq input key))
     ((eq (type-of key) 'string) ;; Kbd code
      (setq input (listify-key-sequence (read-kbd-macro key t)))))
    (symbol-value 'input)))

(defvar ergoemacs-ctl-text (replace-regexp-in-string "[qQ]" "" (ergoemacs-pretty-key "C-q")))
(defvar ergoemacs-alt-text (replace-regexp-in-string "[qQ]" "" (ergoemacs-pretty-key "M-q")))
(defvar ergoemacs-shift-text (replace-regexp-in-string "[qQ]" "" (ergoemacs-pretty-key "S-q")))
(defvar ergoemacs-alt-ctl-text (replace-regexp-in-string "[qQ]" "" (ergoemacs-pretty-key "C-M-q")))

(defun ergoemacs-universal-argument (&optional type)
  "Ergoemacs universal argument.
This is called through `ergoemacs-read-key'"
  (interactive)
  (setq current-prefix-arg '(4))
  (ergoemacs-read-key nil type nil t))

(defun ergoemacs-unchorded-universal-argument (&optional type)
  "Ergoemacs universal argument with unchorded translation setup
This is called through `ergoemacs-read-key'"
  (interactive)
  (ergoemacs-universal-argument 'unchorded))

(defun ergoemacs-ctl-to-alt-universal-argument (&optional type)
  "Ergoemacs universal argument, with ctl-to-alt translation setup.
This is called through `ergoemacs-read-key'"
  (interactive)
  (ergoemacs-universal-argument 'ctl-to-alt))
(defvar ergoemacs-universal-fns
  '(universal-argument
    ergoemacs-universal-argument
    ergoemacs-unchorded-universal-argument
    ergoemacs-ctl-to-alt-universal-argument)
  "Universal argument functions")

(defun ergoemacs-read-event (type &optional pretty-key extra-txt universal)
  "Reads a single event of TYPE.

PRETTY-KEY represents the previous keys pressed in
`ergoemacs-pretty-key' format.

EXTRA-TXT changes the text before the prompt.

UNIVERSAL tells that a universal argument has been pressed, or a
universal argument can be entered.
"
  (let ((universal universal)
        (local-keymap
         (if type (symbol-value
                   (intern (concat "ergoemacs-read-key-" (symbol-name type) "-local-map"))) nil))
        (key-tag (intern (concat ":" (symbol-name type)
                                 (if ergoemacs-read-shift-to-alt "-shift"
                                   "") "-key")))
        ret message-log-max (blink-on nil) tmp
        help-text)
    (when type
      (cond
       ((eq type 'unchorded)
        (setq help-text (concat ", " ergoemacs-alt-text (ergoemacs-unicode-char "→" "->") (ergoemacs-pretty-key "")
                                ", " ergoemacs-ctl-text (ergoemacs-unicode-char "→" "->") ergoemacs-alt-text))))
      (when ergoemacs-read-shift-to-alt
        (setq help-text (concat help-text ", " ergoemacs-shift-text (ergoemacs-unicode-char "→" "->") ergoemacs-alt-text)))
      (setq tmp (where-is-internal 'ergoemacs-read-key-next-key-is-alt local-keymap t))
      (when tmp
        (setq help-text (concat help-text ", " (ergoemacs-pretty-key (key-description tmp)) (ergoemacs-unicode-char "→" "->") ergoemacs-alt-text)))
      (setq tmp (where-is-internal 'ergoemacs-read-key-next-key-is-ctl local-keymap t))
      (when tmp
        (setq help-text (concat help-text ", " (ergoemacs-pretty-key (key-description tmp)) (ergoemacs-unicode-char "→" "->") ergoemacs-ctl-text)))
      (setq tmp (where-is-internal 'ergoemacs-read-key-next-key-is-alt-ctl local-keymap t))
      (when tmp
        (setq help-text (concat help-text ", " (ergoemacs-pretty-key (key-description tmp)) (ergoemacs-unicode-char "→" "->") ergoemacs-alt-ctl-text)))
      (setq tmp (where-is-internal 'ergoemacs-read-key-next-key-is-quoted local-keymap t))
      (when tmp
        (setq help-text (concat help-text ", " (ergoemacs-pretty-key (key-description tmp)) (ergoemacs-unicode-char "→" "->") "Quote"))))
    (while (not ret)
      (unless (minibufferp)
        (message "%s%s%s%s%s%s\t%s"
                 (if ergoemacs-describe-key
                     "Describe key: " "")
                 (if current-prefix-arg
                     (format
                      "%s%s%s %s "
                      (cond
                       ((listp current-prefix-arg)
                        (make-string (round (log (nth 0 current-prefix-arg) 4)) ?u))
                       (t current-prefix-arg))
                      (if universal
                          (if blink-on
                              (if ergoemacs-read-blink
                                  (ergoemacs-unicode-char
                                   ergoemacs-read-blink "-")
                                " ") " ") "")
                      (if (listp current-prefix-arg)
                          (format "%s" 
                                  current-prefix-arg)
                        "")
                      (ergoemacs-unicode-char "▸" ">"))
                   (if universal
                       (format "%s %s "
                               (if universal
                                   (if blink-on
                                       (if ergoemacs-read-blink
                                           (ergoemacs-unicode-char
                                            ergoemacs-read-blink "-")
                                         " ") " ") "")
                               (ergoemacs-unicode-char "▸" ">"))
                     ""))
                 (cond
                  ((eq type 'ctl-to-alt)
                   (format "<Ctl%sAlt> " 
                           (ergoemacs-unicode-char "↔" " to ")))
                  ((eq type 'unchorded)
                   "<Unchorded> ")
                  (t
                   ""))
                 (or pretty-key "")
                 (or extra-txt
                     (if (eq type 'unchorded)
                         ergoemacs-ctl-text ""))
                 (if universal ""
                     (if blink-on
                         (if ergoemacs-read-blink
                             (ergoemacs-unicode-char
                              ergoemacs-read-blink "-")
                           "") ""))
                 (if (and help-text (not universal))
                     (concat "\nTranslations:" (substring help-text 1)) "")))
      (setq blink-on (not blink-on))
      (setq ret (with-timeout (0.4 nil) (read-key)))
      (cond
       ((and ret (not universal)
             (and local-keymap
                  (memq (lookup-key local-keymap (vector ret))
                        ergoemacs-universal-fns)))
        (setq universal t)
        (setq ret nil))
       ((and ret universal) ;; Handle universal arguments.
        (cond
         ((eq ret 45) ;; Negative argument
          (cond
           ((integerp current-prefix-arg)
            (setq current-prefix-arg (- current-prefix-arg)))
           ((eq current-prefix-arg '-)
            (setq current-prefix-arg nil))
           (t
            (setq current-prefix-arg '-)))
          (setq ret nil))
         ((memq ret (number-sequence 48 57)) ;; Number
          (setq ret (- ret 48)) ;; Actual Number.
          (cond
           ((and (integerp current-prefix-arg) (< 0 current-prefix-arg))
            (setq current-prefix-arg (+ ret (* current-prefix-arg 10))))
           ((and (integerp current-prefix-arg) (> 0 current-prefix-arg))
            (setq current-prefix-arg (+ (- ret) (* current-prefix-arg 10))))
           ((and (eq current-prefix-arg '-) (> ret 0))
            (setq current-prefix-arg (- ret))
            (setq ret nil))
           (t
            (setq current-prefix-arg ret)))
          (setq ret nil))
         ((and local-keymap (not current-prefix-arg)
               (memq (lookup-key local-keymap (vector ret))
                     ergoemacs-universal-fns)) ;; Toggle to key-sequence.
          (setq ret nil)
          (setq universal nil))
         ((let (ergoemacs-read-input-keys)
            (or (memq (key-binding
                       (plist-get
                        (ergoemacs-translate (vector ret))
                        key-tag))
                      ergoemacs-universal-fns)
                (and local-keymap
                     (memq (lookup-key local-keymap (vector ret))
                           ergoemacs-universal-fns))))
          ;; Universal argument called.
          (cond
           ((not current-prefix-arg)
            (setq current-prefix-arg '(4))
            (setq ret nil))
           ((listp current-prefix-arg)
            (setq current-prefix-arg (list (* (nth 0 current-prefix-arg) 4)))
            (setq ret nil))
           (t
            (setq universal nil)
            (setq ret nil))))
         ((member (vector ret)
                  (where-is-internal
                   'ergoemacs-read-key-undo-last
                   local-keymap))
          ;; Allow backspace to edit universal arguments.
          (cond
           ((not current-prefix-arg)) ;; Exit  universal argument
           ((and (integerp current-prefix-arg)
                 (= 0 (truncate current-prefix-arg 10))
                 (< 0 current-prefix-arg))
            (setq current-prefix-arg nil)
            (setq ret nil))
           ((and (integerp current-prefix-arg)
                 (= 0 (truncate current-prefix-arg 10))
                 (> 0 current-prefix-arg))
            (setq current-prefix-arg '-)
            (setq ret nil))
           ((integerp current-prefix-arg)
            (setq current-prefix-arg (truncate current-prefix-arg 10))
            (setq ret nil))
           ((listp current-prefix-arg)
            (setq current-prefix-arg
                  (list (expt 4 (- (round (log (nth 0 current-prefix-arg) 4)) 1))))
            (if (equal current-prefix-arg '(1))
                (setq current-prefix-arg nil))
            (setq ret nil))
           ((eq current-prefix-arg '-)
            (setq current-prefix-arg nil)
            (setq ret nil))))))))
    (symbol-value 'ret)))

(defcustom ergoemacs-read-shift-to-alt t
  "When enabled, ergoemacs-mode translates Shift to Alt.
This is done for ctl-to-alt and unchorded translations."
  :group 'ergoemacs-read
  :type 'boolean)

(defcustom ergoemacs-read-swaps
  '(((normal normal) unchorded)
    ((normal unchorded) ctl-to-alt)
    ((normal unchorded) normal)
    ((ctl-to-alt ctl-to-alt) unchorded)
    ((ctl-to-alt unchorded) ctl-to-alt)
    ((unchorded unchorded) ctl-to-alt)
    ((unchorded ctl-to-alt) unchorded))
  "How the translation will be swapped."
  :type '(repeat
          (list
           (list
            (sexp :tag "First Type")
            (sexp :tag "Current Type"))
           (sexp :tag "Translated Type")))
  :group 'ergoemacs-read)

(defcustom ergoemacs-echo-function 'on-translation
  "Shows the function evaluated with a key."
  :type '(choice
          (const :tag "Always echo" t)
          (const :tag "Echo on translations" 'on-translation)
          (const :tag "Don't Echo"))
  :group 'ergoemacs-read)

(defcustom ergoemacs-read-blink "•"
  "Blink character."
  :type '(choice
          (string :tag "Cursor")
          (const :tag "No cursor" nil))
  :group 'ergoemacs-read)

(defun ergoemacs-read-key-swap (&optional first-type current-type)
  "Function to swap key translation.

This function looks up the FIRST-TYPE and CURRENT-TYPE in
`ergoemacs-read-swaps' to figure out the next translation.

If the next translation is not found, default to the normal
translation."
  (interactive)
  (let ((next-swap (assoc (list first-type current-type) ergoemacs-read-swaps)))
    (if next-swap
        (nth 1 next-swap)
      'normal)))

(defun ergoemacs-read-key-undo-last ()
  "Function to undo the last key-press.
This is actually a dummy function.  The actual work is done in `ergoemacs-read-key'"
  (interactive))

(defun ergoemacs-read-key-install-next-key (next-key key pretty kbd)
  "Installs KEY PRETTY-KEY and KBD into NEXT-KEY plist.
Currently will replace the :normal :unchorded and :ctl-to-alt properties."
  (let ((next-key next-key))
    (mapc
     (lambda(variant)
       (let ((var-kbd (intern variant))
             (var-key (intern (concat variant "-key")))
             (var-pretty (intern (concat variant "-pretty")))
             (var-s-kbd (intern (concat variant "-shift")))
             (var-s-key (intern (concat variant "-shift-key")))
             (var-s-pretty (intern (concat variant "-shift-pretty"))))
         (setq next-key (plist-put next-key var-kbd kbd))
         (setq next-key (plist-put next-key var-s-kbd kbd))
         (setq next-key (plist-put next-key var-key key))
         (setq next-key (plist-put next-key var-s-key key))
         (setq next-key (plist-put next-key var-pretty pretty))
         (setq next-key (plist-put next-key var-s-pretty pretty))))
     '(":ctl-to-alt" ":unchorded" ":normal"))
    (symbol-value 'next-key)))

(defun ergoemacs-read-key-next-key-is-alt (&optional type pretty-key)
  "The next key read is an Alt+ key. (or M- )"
  (interactive)
  (let (next-key
        key pretty kbd)
    (setq next-key
          (ergoemacs-translate
           (vector
            (ergoemacs-read-event nil pretty-key ergoemacs-alt-text))))
    (setq key (plist-get next-key ':alt-key))
    (setq pretty (plist-get next-key ':alt-pretty))
    (setq kbd (plist-get next-key ':alt))
    (setq next-key (ergoemacs-read-key-install-next-key next-key key pretty kbd))
    (symbol-value 'next-key)))

(defun ergoemacs-read-key-next-key-is-ctl (&optional type pretty-key)
  "The next key read is an Ctrl+ key. (or C- )"
  (interactive)
  (let (next-key
        key pretty kbd)
    (setq next-key
          (ergoemacs-translate
               (vector
                (ergoemacs-read-event nil pretty-key ergoemacs-ctl-text))))
    (setq key (plist-get next-key ':ctl-key))
    (setq pretty (plist-get next-key ':ctl-pretty))
    (setq kbd (plist-get next-key ':ctl))
    (setq next-key (ergoemacs-read-key-install-next-key next-key key pretty kbd))
    (symbol-value 'next-key)))

(defun ergoemacs-read-key-next-key-is-alt-ctl (&optional type pretty-key)
  "The next key read is an Alt+Ctrl+ key. (or C-M- )"
  (interactive)
  (let (next-key
        key pretty kbd)
    (setq next-key
              (ergoemacs-translate
               (vector
                (ergoemacs-read-event nil pretty-key ergoemacs-alt-ctl-text))))
    (setq key (plist-get next-key ':alt-ctl-key))
    (setq pretty (plist-get next-key ':alt-ctl-pretty))
    (setq kbd (plist-get next-key ':alt-ctl))
    (setq next-key (ergoemacs-read-key-install-next-key next-key key pretty kbd))
    (symbol-value'next-key)))

(defun ergoemacs-read-key-next-key-is-quoted (&optional type pretty-key)
  "The next key read is quoted."
  (interactive)
  (let (next-key
        key pretty kbd)
    (setq next-key (vector (ergoemacs-read-event nil pretty-key "")))
    (setq next-key (ergoemacs-translate next-key))
    (setq key (plist-get next-key ':normal-key))
    (setq pretty (plist-get next-key ':normal-pretty))
    (setq kbd (plist-get next-key ':normal))
    (setq next-key (ergoemacs-read-key-install-next-key next-key key pretty kbd))
    (symbol-value 'next-key)))

(defvar ergoemacs-read-key-normal-local-map
  (let ((map (make-sparse-keymap))
        (no-ergoemacs-advice t))
    (define-key map (if (eq system-type 'windows-nt) [apps] [menu]) 'ergoemacs-read-key-swap)
    (define-key map (read-kbd-macro "DEL") 'ergoemacs-read-key-undo-last)
    (define-key map [f2] 'ergoemacs-universal-argument) ;; Allows editing
    map)
  "Local keymap for `ergoemacs-read-key' with normal translation enabled")

(defvar ergoemacs-read-key-ctl-to-alt-local-map
  (let ((map (make-sparse-keymap))
        (no-ergoemacs-advice t))
    (define-key map (if (eq system-type 'windows-nt) [apps] [menu]) 'ergoemacs-read-key-swap)
    (define-key map (read-kbd-macro "SPC") 'ergoemacs-read-key-next-key-is-alt)
    (define-key map (read-kbd-macro "M-SPC") 'ergoemacs-read-key-next-key-is-alt-ctl)
    (define-key map (read-kbd-macro "DEL")  'ergoemacs-read-key-undo-last)
    (define-key map [f2] 'ergoemacs-universal-argument) ;; Allows editing
    (define-key map "g" 'ergoemacs-read-key-next-key-is-quoted)
    map)
  "Local keymap for `ergoemacs-read-key' with ctl-to-alt translation enabled.")

(defvar ergoemacs-read-key-unchorded-local-map
  (let ((map (make-sparse-keymap))
        (no-ergoemacs-advice t))
    (define-key map (if (eq system-type 'windows-nt) [apps] [menu]) 'ergoemacs-read-key-swap)
    (define-key map (read-kbd-macro "SPC") 'ergoemacs-read-key-next-key-is-quoted)
    (define-key map (read-kbd-macro "M-SPC") 'ergoemacs-read-key-next-key-is-alt-ctl)
    (define-key map "g" 'ergoemacs-read-key-next-key-is-alt)
    (define-key map "G" 'ergoemacs-read-key-next-key-is-alt-ctl)
    (define-key map [f2] 'ergoemacs-universal-argument) ;; Allows editing
    (define-key map (read-kbd-macro "DEL") 'ergoemacs-read-key-undo-last)
    map)
  "Local keymap for `ergoemacs-read-key' with unchorded translation enabled.")

(defun ergoemacs-read-key-call (function &optional record-flag keys)
  "`ergoemacs-mode' replacement for `call-interactively'.

This will call the function with the standard `call-interactively' unless:

- `ergoemacs-describe-key' is non-nil.  In this case,
   `describe-function' is called instead.

-  The function name matches \"self-insert\", then it will send the keys
   by `unread-command-events'.

In addition, when the function is called:

- Add the function count to `keyfreq-table' when `keyfreq-mode'
  is enabled.

- Remove `ergoemacs-this-command' count from `keyfreq-table' when
  `keyfreq-mode' is enabled.

- set `this-command' to the function called.

"
  (cond
   (ergoemacs-describe-key
    (describe-function function)
    (setq ergoemacs-describe-key nil))
   ((condition-case err
        (string-match "self-insert" (symbol-name function))
      (error nil))
    (setq ergoemacs-single-command-keys nil)
    (setq last-input-event keys)
    (setq prefix-arg current-prefix-arg)
    (setq unread-command-events (append (listify-key-sequence keys) unread-command-events))
    (reset-this-command-lengths))
   (t (call-interactively function record-flag keys)
      (when (featurep 'keyfreq)
        (when keyfreq-mode
          (let ((command ergoemacs-this-command) count)
            (setq count (gethash (cons major-mode command) keyfreq-table))
            (cond
             ((not count))
             ((= count 1)
              (remhash (cons major-mode command) keyfreq-table))
             (count
              (puthash (cons major-mode command) (- count 1)
                       keyfreq-table)))
            ;; Add local-fn to counter.
            (setq count (gethash (cons major-mode function) keyfreq-table))
            (puthash (cons major-mode function) (if count (+ count 1) 1)
                     keyfreq-table))))
      (setq this-command function))))

(defvar ergoemacs-read-key-overriding-terminal-local-save nil)
(defvar ergoemacs-read-key-overriding-overlay-save nil)
(defun ergoemacs-read-key-lookup-get-ret (fn)
  "Get ret type for FN.
Returns 'keymap for FN that is a keymap.
If FN is a member of `ergoemacs-universal-fns', return 'universal

If universal is returned, and type first-type is bound, set these
to the appropriate values for `ergoemacs-read-key'.
"
  (let (ret)
    (when (condition-case err (keymapp fn) nil)
      ;; If keymap, continue.
      (setq ret 'keymap))
    (when (memq fn ergoemacs-universal-fns)
      (setq ret 'universal)
      (when (and (boundp 'type)
                 (boundp 'first-type)
                 (memq fn '(universal-argument ergoemacs-universal-argument)))
        (setq type 'normal
              first-type 'normal))
      (when (and (boundp 'type)
                 (boundp 'first-type)
                 (memq fn '(ergoemacs-unchorded-universal-argument)))
        (setq type 'unchorded
              first-type 'unchorded))
      (when (and (boundp 'type)
                 (boundp 'first-type)
                 (memq fn '(ergoemacs-ctl-to-alt-universal-argument)))
        (setq type 'ctl-to-alt
              first-type 'unchorded)))
    (symbol-value 'ret)))

(defun ergoemacs-read-key-lookup (prior-key prior-pretty-key key pretty-key force-key)
  "Lookup KEY and run if necessary.

PRETTY-KEY is the ergoemacs-mode pretty representation of the key

PRIOR-KEY is the prior key press recorded.  For example, for the
key sequence, <apps> k the PRIOR-KEY is 'apps

FORCE-KEY forces keys like <escape> to work properly.
"
  (prog1
      (let* (ergoemacs-read-input-keys
             ergoemacs-shortcut-override-mode
             ;; Turn on `ergoemacs-shortcut-keys' layer when the
             ;; prior-key is defined on `ergoemacs-read-input-keymap'.
             ;; This way keys like <apps> will read the from the
             ;; `ergoemacs-shortcut-keys' layer and then discontinue
             ;; reading from that layer.
             ;;
             ;; Also turn on ergoemacs-shortcut-keys as long as this
             ;; isn't a recursive call.
             (ergoemacs-shortcut-keys
              (if prior-key
                  (lookup-key ergoemacs-read-input-keymap prior-key)
                (not (and (boundp 'ergoemacs-read-key-recursive)
                   ergoemacs-read-key-recursive))))
             lookup
             tmp-overlay use-override
             ergoemacs-read-key-recursive
             tmp ret fn hash)
        (when (or (equal key [3]) (equal key [24])) ;; C-c or C-x
          (setq ergoemacs-shortcut-keys nil))
        (setq ergoemacs-read-key-recursive t)
        ;; Install overriding-terminal-local-map without
        ;; ergoemacs-read-key The composed map with ergoemacs-read-key
        ;; will be installed on the ergoemacs-post-command-hook
        (when overriding-terminal-local-map
          (setq lookup (gethash
                        (md5
                         (format "override-terminal-read: %s"
                                overriding-terminal-local-map))
                        ergoemacs-extract-map-hash))
          (when lookup
            (setq use-override t)
            (setq overriding-terminal-local-map lookup)))
        
        ;; Install overriding-local-map
        (when overriding-local-map 
          (setq lookup (gethash
                        (md5
                         (format "override-local-read: %s"
                                 overriding-local-map))
                        ergoemacs-extract-map-hash))
          (when lookup
            (setq use-override t)
            (setq overriding-local-map lookup)))
        (when (get-char-property (point) 'keymap)
          (setq lookup (gethash
                        (md5
                         (format "char-map-read:%s" (get-char-property (point) 'keymap)))
                        ergoemacs-extract-map-hash))
          (when lookup
            (setq tmp-overlay (make-overlay (max (- (point) 1) (point-min))
                                            (min (+ (point) 1) (point-max))))
            (overlay-put tmp-overlay 'keymap lookup)
            (overlay-put tmp-overlay 'priority 536870910)))
        (unwind-protect
            (cond
             ((progn
                (setq tmp (lookup-key input-decode-map key))
                (when (and tmp (integerp tmp))
                  (setq tmp nil))
                (unless tmp
                  (setq tmp (lookup-key local-function-key-map key))
                  (when (and tmp (integerp tmp))
                    (setq tmp nil))
                  (unless tmp
                    (setq tmp (lookup-key key-translation-map key))
                    (when (and tmp (integerp tmp))
                      (setq tmp nil))))
                tmp)
              ;; Should use emacs key translation.
              (cond
               ((keymapp tmp)
                (setq ret 'keymap))
               ((and ergoemacs-describe-key (vectorp tmp))
                (setq ergoemacs-single-command-keys nil)
                (message "%s translates to %s" pretty-key
                         (ergoemacs-pretty-key (key-description tmp)))
                (setq ergoemacs-describe-key nil)
                (setq ret 'translate))
               ((vectorp tmp)
                (setq ergoemacs-single-command-keys nil)
                (setq last-input-event tmp)
                (setq prefix-arg current-prefix-arg)
                (setq unread-command-events (append (listify-key-sequence tmp) unread-command-events))
                (reset-this-command-lengths)
                (when (and ergoemacs-echo-function
                           (boundp 'pretty-key-undefined))
                  (let (message-log-max)
                    (if (string= pretty-key-undefined pretty-key)
                        (when (eq ergoemacs-echo-function t)
                          (message "%s%s%s" pretty-key
                                 (ergoemacs-unicode-char "→" "->")
                                 (ergoemacs-pretty-key (key-description tmp))))
                      (message "%s%s%s (from %s)"
                               pretty-key
                               (ergoemacs-unicode-char "→" "->")
                               (ergoemacs-pretty-key (key-description tmp))
                               pretty-key-undefined))))
                (when lookup
                  (define-key lookup [ergoemacs-single-command-keys] 'ignore)
                  (setq ergoemacs-read-key-overriding-terminal-local-save overriding-terminal-local-map)
                  (setq overriding-terminal-local-map lookup))
                (setq ret 'translate))))
             ;; Global override
             ((progn
                (setq fn (lookup-key ergoemacs-global-override-keymap key))
                (setq ret (ergoemacs-read-key-lookup-get-ret fn))
                (or ret (condition-case err
                            (interactive-form fn)
                          nil)))
              (unless ret
                (setq fn (or (command-remapping fn (point)) fn))
                (setq ergoemacs-single-command-keys key)
                (when (and ergoemacs-echo-function
                           (boundp 'pretty-key-undefined))
                  (let (message-log-max)
                    (if (string= pretty-key-undefined pretty-key)
                        (when (eq ergoemacs-echo-function t)
                          (message "%s%s%s" pretty-key
                                   (ergoemacs-unicode-char "→" "->")
                                   (symbol-name fn)))
                      (message "%s%s%s (from %s)"
                               pretty-key
                               (ergoemacs-unicode-char "→" "->")
                               (symbol-name fn)
                               pretty-key-undefined))))
                (ergoemacs-read-key-call fn nil key)
                (setq ergoemacs-single-command-keys nil)
                (setq ret 'global-function-override)))
             ;; Is there an local override function?
             ((progn
                (setq fn (ergoemacs-get-override-function key))
                (setq ret (ergoemacs-read-key-lookup-get-ret fn))
                (or ret (condition-case err (interactive-form fn) nil)))
              (unless ret
                (ergoemacs-read-key-call fn nil key)
                (setq ret 'local-function-override)))
             ;; Does this call a function?
             ((progn
                (setq hash (gethash key ergoemacs-command-shortcuts-hash))
                (setq fn (key-binding key))
                (setq ret (ergoemacs-read-key-lookup-get-ret fn))
                (or ret
                    (condition-case err
                        (interactive-form fn)
                      nil)))
              (unless ret
                (cond
                 ((and hash (eq 'string (type-of (nth 0 hash)))
                       (memq (nth 1 hash) '(ctl-to-alt unchorded normal)))
                  ;; Reset the `ergoemacs-read-key'
                  ;; List in form of key type first-type
                  (setq ret (list (nth 0 hash) (nth 1 hash) (nth 1 hash))))
                 ((and hash (eq 'string (type-of (nth 0 hash))))
                  (setq ergoemacs-mark-active mark-active)
                  (setq ergoemacs-single-command-keys key)
                  (setq prefix-arg current-prefix-arg)
                  (setq unread-command-events (append (listify-key-sequence (read-kbd-macro (nth 0 hash))) unread-command-events))
                  (when lookup
                    (define-key lookup [ergoemacs-single-command-keys] 'ignore)
                    (if (not use-override)
                        (setq ergoemacs-read-key-overriding-overlay-save tmp-overlay)
                      (setq ergoemacs-read-key-overriding-terminal-local-save overriding-terminal-local-map)
                      (setq overriding-terminal-local-map lookup)))
                  (setq ret 'kbd-shortcut))
                 ((and hash
                       (condition-case err
                           (interactive-form (nth 0 hash))
                         (error nil)))
                  (when (and ergoemacs-echo-function
                             (boundp 'pretty-key-undefined))
                    (let (message-log-max)
                      (if (string= pretty-key-undefined pretty-key)
                          (when (eq ergoemacs-echo-function t)
                            (message "%s%s%s" pretty-key
                                     (ergoemacs-unicode-char "→" "->")
                                     (symbol-name (nth 0 hash))))
                        (message "%s%s%s (from %s)"
                                 pretty-key
                                 (ergoemacs-unicode-char "→" "->")
                                 (symbol-name (nth 0 hash))
                                 pretty-key-undefined))))
                  (ergoemacs-shortcut-remap (nth 0 hash))
                  (setq ergoemacs-single-command-keys nil)
                  (setq ret 'function-remap))
                 ((and ergoemacs-shortcut-keys (not ergoemacs-describe-key)
                       (not ergoemacs-single-command-keys))
                  (when (and ergoemacs-echo-function
                             (boundp 'pretty-key-undefined))
                    (let (message-log-max)
                      (if (nth 0 hash)
                          (setq fn (nth 0 hash))
                        (setq fn (key-binding key))
                        (setq fn (or (command-remapping fn (point)) fn)))
                      (if (string= pretty-key-undefined pretty-key)
                          (when (eq ergoemacs-echo-function t)
                            (message "%s%s%s;" pretty-key
                                     (ergoemacs-unicode-char "→" "->")
                                     fn))
                        (message "%s%s%s (from %s);"
                                 pretty-key
                                 (ergoemacs-unicode-char "→" "->")
                                 fn
                                 pretty-key-undefined))))
                  ;; There is some issue with these keys.  Read-key thinks it
                  ;; is in a minibuffer, so the recurive minibuffer error is
                  ;; raised unless these are put into unread-command-events.
                  (setq ergoemacs-mark-active mark-active)
                  (setq ergoemacs-single-command-keys key)
                  (setq prefix-arg current-prefix-arg)
                  (setq unread-command-events
                        (append (listify-key-sequence key) unread-command-events))
                  (when lookup
                    (define-key lookup [ergoemacs-single-command-keys] 'ignore)
                    (if (not use-override)
                        (setq ergoemacs-read-key-overriding-overlay-save tmp-overlay)
                      (setq ergoemacs-read-key-overriding-terminal-local-save overriding-terminal-local-map)
                      (setq overriding-terminal-local-map lookup)))
                  (setq ret 'shortcut-workaround))
                 (t
                  (setq fn (or (command-remapping fn (point)) fn))
                  (when (memq fn ergoemacs-universal-fns)
                    (setq ret 'universal)
                    (when (and (boundp 'type)
                               (boundp 'first-type)
                               (memq fn '(universal-argument ergoemacs-universal-argument)))
                      (setq type 'normal
                            first-type 'normal))
                    (when (and (boundp 'type)
                               (boundp 'first-type)
                               (memq fn '(ergoemacs-unchorded-universal-argument)))
                      (setq type 'unchorded
                            first-type 'unchorded))
                    (when (and (boundp 'type)
                               (boundp 'first-type)
                               (memq fn '(ergoemacs-ctl-to-alt-universal-argument)))
                      (setq type 'ctl-to-alt
                            first-type 'unchorded)))
                  (unless ret
                    (setq ergoemacs-single-command-keys key)
                    (when (and ergoemacs-echo-function
                               (boundp 'pretty-key-undefined))
                      (let (message-log-max)
                        (if (string= pretty-key-undefined pretty-key)
                            (when (eq ergoemacs-echo-function t)
                              (message "%s%s%s" pretty-key
                                       (ergoemacs-unicode-char "→" "->")
                                       (symbol-name fn)))
                          (message "%s%s%s (from %s)"
                                   pretty-key
                                   (ergoemacs-unicode-char "→" "->")
                                   (symbol-name fn)
                                   pretty-key-undefined))))
                    (ergoemacs-read-key-call fn nil key)
                    (setq ergoemacs-single-command-keys nil)
                    (setq ret 'function))))))
             ;; Does this call an override or major/minor mode function?
             ((progn
                (setq fn (or
                          ;; Call major/minor mode key?
                          (ergoemacs-with-major-and-minor-modes 
                           (key-binding key))
                          ;; Call unbound or global key?
                          (if (eq (lookup-key ergoemacs-unbind-keymap key) 'ergoemacs-undefined) 'ergoemacs-undefined
                            (let (ergoemacs-read-input-keys)
                              (if (keymapp (key-binding key))
                                  (setq ret 'keymap)
                                (ergoemacs-with-global
                                 (key-binding key)))))))
                (setq ret (ergoemacs-read-key-lookup-get-ret fn))
                (or ret
                    (condition-case err
                        (interactive-form fn)
                      nil)))
              (unless ret
                (setq fn (or (command-remapping fn (point)) fn))
                (setq ergoemacs-single-command-keys key)
                (let (message-log-max)
                  (if (string= pretty-key-undefined pretty-key)
                      (message "%s%s%s" pretty-key
                               (ergoemacs-unicode-char "→" "->")
                               fn)
                    (message "%s%s%s (from %s)"
                             pretty-key
                             (ergoemacs-unicode-char "→" "->")
                             fn
                             pretty-key-undefined)))
                (ergoemacs-read-key-call fn nil key)
                (setq ergoemacs-single-command-keys nil)
                (setq ret 'function-global-or-override))))
          (when (and tmp-overlay (not ergoemacs-read-key-overriding-overlay-save))
            (delete-overlay tmp-overlay)))
        (symbol-value 'ret))
    ;; Turn off read-input-keys for shortcuts
    (when ergoemacs-single-command-keys
      (setq ergoemacs-read-input-keys nil))))

(defun ergoemacs-read-key (&optional key type initial-key-type universal)
  "Read keyboard input and execute command.
The KEY is the keyboard input where the reading begins.  If nil,
read the whole keymap.

TYPE is the keyboard translation type.
It can be: 'ctl-to-alt 'unchorded 'normal.

INITIAL-KEY-TYPE represents the translation type for the initial KEY.
It can be: 'ctl-to-alt 'unchorded 'normal.

UNIVERSAL allows ergoemacs-read-key to start with universal
argument prompt.
"
  (let ((continue-read t)
        (real-type (or type 'normal))
        (first-type (or type 'normal))
        pretty-key
        pretty-key-undefined
        next-key
        (key key)
        key-trial
        pretty-key-trial
        orig-pretty-key
        (type (or initial-key-type 'normal))
        base
        local-keymap
        local-fn
        force-key
        key-trials
        real-read
        (first-universal universal)
        (curr-universal nil)
        input tmp)
    (setq input (ergoemacs-to-sequence key)
          key nil)
    (setq local-keymap
          (symbol-value
           (intern (concat "ergoemacs-read-key-" (symbol-name type) "-local-map"))))
    (setq base (concat ":" (symbol-name type)
                       (if ergoemacs-read-shift-to-alt "-shift"
                         "")))
    (while continue-read
      (setq continue-read nil
            force-key nil)
      (when (and (not input) real-type)
        (setq type real-type)
        (setq curr-universal first-universal)
        (setq base (concat ":" (symbol-name type)
                           (if ergoemacs-read-shift-to-alt "-shift"
                             "")))
        (setq local-keymap
              (symbol-value
               (intern (concat "ergoemacs-read-key-" (symbol-name type) "-local-map"))))
        (setq real-type nil))
      (setq real-read (not input))
      (setq next-key (vector
                      (or (pop input)
                          ;; Echo key sequence
                          ;; get next key
                          (ergoemacs-read-event type pretty-key nil curr-universal))))
      (setq next-key (ergoemacs-translate next-key))
      (setq tmp (plist-get next-key ':normal))
      (when (string= tmp "ESC")
        (setq tmp "<escape>"))
      (if (string= tmp (key-description
                        (ergoemacs-key-fn-lookup 'keyboard-quit)))
          (if (and (not key) (minibufferp))
              (minibuffer-keyboard-quit)
            (unless (minibufferp)
              (let (message-log-max)
                (message "%s%s%s Canceled with %s"
                         (if ergoemacs-describe-key
                             "Help for: " "")
                         (cond
                          ((eq type 'ctl-to-alt)
                           (format "<Ctl%sAlt> " 
                                   (ergoemacs-unicode-char "↔" " to ")))
                          ((eq type 'unchorded)
                           "<Unchorded> ")
                          (t
                           ""))
                         (or pretty-key "") 
                         (if ergoemacs-use-ergoemacs-key-descriptions
                             (plist-get next-key ':normal-pretty)
                           (plist-get next-key ':normal)))))
            (setq ergoemacs-describe-key nil))
        (setq tmp (plist-get next-key ':normal-key))
        ;; See if there is a local equivalent of this...
        (if real-read
            (setq local-fn (lookup-key local-keymap tmp))
          (setq local-fn nil))
        (if (eq local-fn 'ergoemacs-read-key-undo-last)
            (if (= 0 (length key))
                (setq continue-read nil) ;; Exit read-key
              (setq continue-read t ;; Undo last key
                    input (ergoemacs-to-sequence (substring key 0 (- (length key) 1)))
                    real-read nil
                    real-type type)
              (setq key nil
                    pretty-key nil
                    type 'normal
                    key-trial nil
                    key-trials nil
                    pretty-key-trial nil
                    pretty-key nil)
              (setq base (concat ":" (symbol-name type)
                                 (if ergoemacs-read-shift-to-alt "-shift"
                                   ""))
                    local-keymap
                    (symbol-value
                     (intern (concat "ergoemacs-read-key-" (symbol-name type) "-local-map")))))
          (if (and (eq local-fn 'ergoemacs-read-key-swap)
                   (or (not curr-universal) key))
              (progn
                ;; Swap translation
                (setq type (ergoemacs-read-key-swap first-type type)
                      continue-read t)
                (setq base (concat ":" (symbol-name type)
                                   (if ergoemacs-read-shift-to-alt "-shift"
                                     "")))
                (setq local-keymap
                      (symbol-value
                       (intern (concat "ergoemacs-read-key-" (symbol-name type) "-local-map")))))
            (setq curr-universal nil)
            (when (or (not (condition-case err (interactive-form local-fn) (error nil)))
                      (eq local-fn 'ergoemacs-read-key-swap))
              ;; Either the `ergoemacs-read-key-swap' is not applicable,
              ;; or not specified correctly.  Therefore set local-fn to
              ;; nil.
              (setq local-fn nil))
            ;; Change input type for next key press.
            (when (memq local-fn '(ergoemacs-read-key-next-key-is-alt
                                   ergoemacs-read-key-next-key-is-ctl
                                   ergoemacs-read-key-next-key-is-alt-ctl
                                   ergoemacs-read-key-next-key-is-quoted))
              (setq next-key (funcall local-fn type pretty-key))
              (setq force-key t)
              (setq local-fn nil))
            (if local-fn
                (ergoemacs-read-key-call local-fn)
              (setq pretty-key-undefined nil)
              ;; Now we have the 'next-key, try to find a function/keymap
              ;; completion.
              (setq key-trials nil)
              ;; This is the order that ergoemacs-read-key tries keys:
              (push base key-trials)
              (when ergoemacs-read-shift-to-alt
                (push (replace-regexp-in-string "-shift" "" base) key-trials))
              (push ":shift-translated" key-trials)
              (when (and key ergoemacs-translate-emacs-keys)
                (setq tmp (gethash (plist-get next-key
                                              (intern (concat base "-key")))
                                   ergoemacs-command-shortcuts-hash))
                (when (and tmp
                           (condition-case err
                               (interactive-form (nth 0 tmp))
                             (error nil)))
                  (mapc
                   (lambda(key)
                     (let ((key-base (concat ":" (md5 (format "%s" key))))
                           (ergoemacs-use-ergoemacs-key-descriptions t))
                       ;; First add translation to next-key
                       (setq next-key
                             (plist-put next-key
                                        (intern (concat key-base "-key"))
                                        key))
                       (setq next-key
                             (plist-put next-key
                                        (intern key-base)
                                        (key-description key)))
                       (setq next-key
                             (plist-put next-key
                                        (intern (concat key-base "-pretty"))
                                        (ergoemacs-pretty-key
                                         (plist-get next-key (intern key-base)))))
                       ;; Now add to list to check.
                       (push key-base key-trials)))
                   (ergoemacs-shortcut-function-binding (nth 0 tmp)))))
              (when ergoemacs-translate-keys
                (push ":raw" key-trials)
                (push ":ctl" key-trials)
                (push ":alt" key-trials)
                (push ":alt-ctl" key-trials)
                (push ":raw-shift" key-trials)
                (push ":ctl-shift" key-trials)
                (push ":alt-shift" key-trials)
                (push ":alt-ctl-shift" key-trials))
              (setq key-trials (reverse key-trials))
              (unless
                  (catch 'ergoemacs-key-trials
                    (while key-trials
                      (setq key-trial nil)
                      (while (and key-trials (not key-trial))
                        (setq tmp (pop key-trials))
                        ;; If :shift-translated is nil, go to next option.
                        (when (plist-get next-key (intern (concat tmp "-key")))
                          (setq key-trial
                                (if key
                                    (vconcat key (plist-get next-key (intern (concat tmp "-key"))))
                                  (plist-get next-key (intern (concat tmp "-key"))))
                                pretty-key-trial
                                (if pretty-key
                                    (concat pretty-key
                                            (plist-get next-key
                                                       (intern (concat tmp (if ergoemacs-use-ergoemacs-key-descriptions
                                                                               "-pretty" "")))))
                                  (plist-get next-key
                                             (intern (concat tmp (if ergoemacs-use-ergoemacs-key-descriptions
                                                                     "-pretty" ""))))))))
                      (unless pretty-key-undefined
                        (setq pretty-key-undefined pretty-key-trial))
                      (setq local-fn (ergoemacs-read-key-lookup key pretty-key
                                                                key-trial pretty-key-trial
                                                                force-key))
                      (cond
                       ((eq local-fn 'keymap)
                        (setq continue-read t
                              key key-trial
                              pretty-key pretty-key-trial)
                        ;; Found, exit
                        (throw 'ergoemacs-key-trials t))
                       ((eq (type-of local-fn) 'cons)
                        ;; ergoemacs-shortcut reset ergoemacs-read-key
                        (setq continue-read t
                              input (ergoemacs-to-sequence (nth 0 local-fn))
                              key nil
                              pretty-key nil
                              type 'normal
                              real-type (nth 1 local-fn)
                              key-trial nil
                              key-trials nil
                              pretty-key-trial nil
                              first-type (nth 2 local-fn))
                        (setq base (concat ":" (symbol-name type)
                                           (if ergoemacs-read-shift-to-alt "-shift"
                                             "")))
                        ;; Found, exit
                        (throw 'ergoemacs-key-trials t))
                       ((and (eq local-fn 'universal)
                             (not current-prefix-arg))
                        (setq curr-universal t
                              continue-read t
                              key nil
                              pretty-key nil
                              key-trial nil
                              key-trials nil
                              pretty-key-trial nil
                              current-prefix-arg '(4))
                        (setq base (concat ":" (symbol-name type)
                                           (if ergoemacs-read-shift-to-alt "-shift"
                                             "")))
                        (throw 'ergoemacs-key-trials t))
                       ((and (eq local-fn 'universal)
                             (listp current-prefix-arg))
                        (setq curr-universal t
                              continue-read t
                              key nil
                              pretty-key nil
                              key-trial nil
                              key-trials nil
                              pretty-key-trial nil
                              current-prefix-arg (list (* 4 (nth 0 current-prefix-arg))))
                        (setq base (concat ":" (symbol-name type)
                                           (if ergoemacs-read-shift-to-alt "-shift"
                                             "")))
                        (throw 'ergoemacs-key-trials t))
                       (local-fn
                        ;; Found exit
                        (throw 'ergoemacs-key-trials t)))
                      ;; Not found, try the next in the trial
                      (unless key-trials ;; exit
                        (setq key-trial nil)))
                    nil)
                ;; Could not find the key.
                (beep)
                (unless (minibufferp)
                  (let (message-log-max)
                    (message "%s is undefined!" pretty-key-undefined))))))))))
  (setq ergoemacs-describe-key nil))

(defun ergoemacs-define-key (keymap key def)
  "Defines KEY in KEYMAP to be DEF.
Similar to `define-key'.

DEF can be:
1. A function; If globally defined, this is defined by
   `ergoemacs-shortcut-remap'
2. A list of functions
3. A keymap
4. A kbd-code that this shortcuts to with `ergoemacs-read'

"
  (cond
   ((eq 'cons (type-of def))
    (let (found)
      (if (condition-case err
              (stringp (nth 0 def))
            (error nil))
          (if (and (boundp 'setup-ergoemacs-keymap) setup-ergoemacs-keymap)
              (progn
                (puthash (read-kbd-macro (key-description key) t)
                         `(,(nth 0 def) ,(nth 1 def))
                         ergoemacs-command-shortcuts-hash)
                (define-key ergoemacs-shortcut-keymap key
                  'ergoemacs-shortcut))
            (unless (lookup-key keymap key)
              (cond
               ((condition-case err
                    (interactive-form (nth 0 def))
                  (error nil))
                (define-key keymap key
                  `(lambda(&optional arg)
                     (interactive "P")
                     (setq this-command last-command) ; Don't record this command.
                     ;; (setq prefix-arg current-prefix-arg)
                     (ergoemacs-shortcut-remap ,(nth 0 def)))))
               (t
                (define-key keymap key
                `(lambda(&optional arg)
                   (interactive "P")
                   (setq this-command last-command) ; Don't record this command.
                   ;; (setq prefix-arg current-prefix-arg)
                   (ergoemacs-read-key ,(nth 0 def) ',(nth 1 def))))))))
        (mapc
         (lambda(new-def)
           (unless found
             (when (condition-case err
                       (interactive-form new-def)
                     (error nil))
               (setq found
                     (ergoemacs-define-key keymap key new-def)))))
         def))
      (symbol-value 'found)))
   ((condition-case err
        (interactive-form def)
      (error nil))
    (cond
     ;; only setup on `ergoemacs-shortcut-keymap' when setting up
     ;; ergoemacs default keymap.
     ((and (boundp 'setup-ergoemacs-keymap) setup-ergoemacs-keymap
           (memq def '(ergoemacs-ctl-c ergoemacs-ctl-x)))
      (define-key ergoemacs-shortcut-keymap key def))
     ((and (not (string-match "\\(mouse\\|wheel\\)" (key-description key)))
           (boundp 'setup-ergoemacs-keymap) setup-ergoemacs-keymap
           (ergoemacs-shortcut-function-binding def))
      (puthash (read-kbd-macro (key-description key) t)
               (list def 'global) ergoemacs-command-shortcuts-hash)
      (if (ergoemacs-is-movement-command-p def)
          (if (let (case-fold-search) (string-match "\\(S-\\|[A-Z]$\\)" (key-description key)))
              (define-key ergoemacs-shortcut-keymap key 'ergoemacs-shortcut-movement-no-shift-select)
            (define-key ergoemacs-shortcut-keymap key 'ergoemacs-shortcut-movement))
        (define-key ergoemacs-shortcut-keymap key 'ergoemacs-shortcut)))     
     ((or (and (boundp 'setup-ergoemacs-keymap) setup-ergoemacs-keymap)
          (not (lookup-key keymap key)))
      (define-key keymap key def)))
    t)
   ((condition-case err
        (keymapp (symbol-value def))
      (error nil))
    (define-key keymap key (symbol-value def))
    t)
   ((condition-case err
        (stringp def)
      (error nil))
    (if (and (boundp 'setup-ergoemacs-keymap) setup-ergoemacs-keymap)
        (progn
          (puthash (read-kbd-macro (key-description key) t)
                   `(,def nil)
                   ergoemacs-command-shortcuts-hash)
          (if (ergoemacs-is-movement-command-p def)
              (if (let (case-fold-search) (string-match "\\(S-\\|[A-Z]$\\)" (key-description key)))
                  (define-key ergoemacs-shortcut-keymap key 'ergoemacs-shortcut-movement-no-shift-select)
                (define-key ergoemacs-shortcut-keymap key 'ergoemacs-shortcut-movement))
            (define-key ergoemacs-shortcut-keymap key 'ergoemacs-shortcut)))
      (unless (lookup-key keymap key)
        (define-key keymap key
          `(lambda(&optional arg)
             (interactive "P")
             (setq this-command last-command) ; Don't record this command.
             ;; (setq prefix-arg current-prefix-arg)
             (ergoemacs-read-key ,def)))))
    
    t)
   (t nil)))

(defvar ergoemacs-ignored-prefixes '("C-h" "<f1>" "C-x" "C-c" "ESC" "<escape>"))

(defun ergoemacs-setup-keys-for-layout (layout &optional base-layout)
  "Setup keys based on a particular LAYOUT. All the keys are based on QWERTY layout."
  (ergoemacs-setup-translation layout base-layout)
  ;; Reset shortcuts layer.
  (setq ergoemacs-command-shortcuts-hash (make-hash-table :test 'equal))
  (let ((setup-ergoemacs-keymap t))
    (ergoemacs-setup-keys-for-keymap ergoemacs-keymap))
  (ergoemacs-setup-fast-keys)
  (let ((x (assq 'ergoemacs-mode minor-mode-map-alist)))
    ;; Install keymap
    (if x
        (setq minor-mode-map-alist (delq x minor-mode-map-alist)))
    (add-to-list 'minor-mode-map-alist
                 `(ergoemacs-mode  ,(symbol-value 'ergoemacs-keymap))))
  (easy-menu-define ergoemacs-menu ergoemacs-keymap
    "ErgoEmacs menu"
    `("ErgoEmacs"
      ,(ergoemacs-get-layouts-menu)
      ,(ergoemacs-get-themes-menu)
      "--"
      ("Ctrl+C and Ctrl+X behavior"
       ["Ctrl+C and Ctrl+X are for Emacs Commands"
        (lambda()
          (interactive)
          (set-default 'ergoemacs-handle-ctl-c-or-ctl-x 'only-C-c-and-C-x))
        :style radio
        :selected (eq ergoemacs-handle-ctl-c-or-ctl-x 'only-C-c-and-C-x)]
       ["Ctrl+C and Ctrl+X are only Copy/Cut"
        (lambda()
          (interactive)
          (set-default 'ergoemacs-handle-ctl-c-or-ctl-x 'only-copy-cut))
        :style radio
        :selected (eq ergoemacs-handle-ctl-c-or-ctl-x 'only-copy-cut)]
       ["Ctrl+C and Ctrl+X are both Emacs Commands & Copy/Cut"
        (lambda()
          (interactive)
          (set-default 'ergoemacs-handle-ctl-c-or-ctl-x 'both))
        :style radio
        :selected (eq ergoemacs-handle-ctl-c-or-ctl-x 'both)]
       ["Customize Ctrl+C and Ctrl+X Cut/Copy Timeout"
        (lambda() (interactive)
          (customize-variable 'ergoemacs-ctl-c-or-ctl-x-delay))])
      ("Paste behavior"
       ["Repeating Paste pastes multiple times"
        (lambda()
          (interactive)
          (set-default 'ergoemacs-smart-paste nil))
        :style radio
        :selected (eq ergoemacs-smart-paste 'nil)]
       ["Repeating Paste cycles through previous pastes"
        (lambda()
          (interactive)
          (set-default 'ergoemacs-smart-paste t))
        :style radio
        :selected (eq ergoemacs-smart-paste 't)]
       ["Repeating Paste starts browse-kill-ring"
        (lambda()
          (interactive)
          (set-default 'ergoemacs-smart-paste 'browse-kill-ring))
        :style radio
        :enable (condition-case err (interactive-form 'browse-kill-ring)
                  (error nil))
        :selected (eq ergoemacs-smart-paste 'browse-kill-ring)])
      "--"
      ["Make Bash aware of ergoemacs keys"
       (lambda () (interactive)
         (call-interactively 'ergoemacs-bash)) t]
      "--"
      ["Use Menus"
       (lambda() (interactive)
         (setq ergoemacs-use-menus (not ergoemacs-use-menus))
         (if ergoemacs-use-menus
             (progn
               (require 'ergoemacs-menus)
               (ergoemacs-menus-on))
           (when (featurep 'ergoemacs-menus)
             (ergoemacs-menus-off))))
       :style toggle :selected (symbol-value 'ergoemacs-use-menus)]
      "--"
      ;; ["Generate Documentation"
      ;;  (lambda()
      ;;    (interactive)
      ;;    (call-interactively 'ergoemacs-extras)) t]
      ["Customize Ergoemacs"
       (lambda ()
         (interactive)
         (customize-group 'ergoemacs-mode)) t]
      ["Save Settings for Future Sessions"
       (lambda ()
         (interactive)
         (customize-save-variable 'ergoemacs-smart-paste ergoemacs-smart-paste)
         (customize-save-variable 'ergoemacs-use-menus ergoemacs-use-menus)
         (customize-save-variable 'ergoemacs-theme ergoemacs-theme)
         (customize-save-variable 'ergoemacs-keyboard-layout ergoemacs-keyboard-layout)
         (customize-save-variable 'ergoemacs-ctl-c-or-ctl-x-delay ergoemacs-ctl-c-or-ctl-x-delay)
         (customize-save-variable 'ergoemacs-handle-ctl-c-or-ctl-x ergoemacs-handle-ctl-c-or-ctl-x)
         (customize-save-variable 'ergoemacs-use-menus ergoemacs-use-menus)
         (customize-save-customized)) t]
      ["Exit ErgoEmacs"
       (lambda ()
         (interactive)
         (ergoemacs-mode -1)) t]))
  
  (let ((existing (assq 'ergoemacs-mode minor-mode-map-alist)))
    (if existing
        (setcdr existing ergoemacs-keymap)
      (push (cons 'ergoemacs-mode ergoemacs-keymap) minor-mode-map-alist)))
  (ergoemacs-mode-line)
  ;; Set appropriate mode-line indicator
  (ergoemacs-setup-backward-compatability))

(defvar ergoemacs-extract-map-hash (make-hash-table :test 'equal))

(defvar ergoemacs-prefer-shortcuts t ;; Prefer shortcuts.
  "Prefer shortcuts")

(defvar ergoemacs-command-shortcuts-hash (make-hash-table :test 'equal)
  "List of command shortcuts.")

(defvar ergoemacs-repeat-shortcut-keymap (make-sparse-keymap)
  "Keymap for repeating often used shortcuts like C-c C-c.")

(defvar ergoemacs-repeat-shortcut-msg ""
  "Message for repeating keyboard shortcuts like C-c C-c")

(defun ergoemacs-shortcut-timeout ()
  (let (message-log-max)
    (unless (current-message)
      (message ergoemacs-repeat-shortcut-msg)))
  (set-temporary-overlay-map ergoemacs-repeat-shortcut-keymap))

(defvar ergoemacs-current-extracted-map nil
  "Current extracted map for `ergoemacs-shortcut' defined functions")

(defvar ergoemacs-first-extracted-variant nil
  "Current extracted variant")

(defcustom ergoemacs-shortcut-ignored-functions
  '(undo-tree-visualize)
  "Ignored functions for `ergoemacs-shortcut'."
  :group 'ergoemacs-mode
  :type '(repeat
          (symbol :tag "Function to ignore:")))

(defcustom ergoemacs-shortcuts-do-not-lookup
  '(execute-extended-command)
  "Functions that `ergoemacs-mode' does not lookup equivalent key-bindings for. "
  :group 'ergoemacs-mode
  :type '(repeat
          (symbol :tag "Function to call literally:")))

(defun ergoemacs-get-override-function (keys)
  "See if KEYS has an overriding function.
If so, return the function, otherwise return nil.

First it looks up ergoemacs user commands.  These are defined in the key
<ergoemacs-user> KEYS

If there is no ergoemacs user commands, look in override map.
This is done by looking up the function for KEYS with
`ergoemacs-with-overrides'.

If the overriding function is found make sure it isn't the key
defined in the major/minor modes (by
`ergoemacs-with-major-and-minor-modes'). "
  (let ((override (key-binding (read-kbd-macro (format "<ergoemacs-user> %s" (key-description keys)))))
        cmd1 cmd2)
    (unless (condition-case err
              (interactive-form override)
            (error nil))
      (setq override nil))
    (unless override
      (setq cmd1 (ergoemacs-with-overrides
                  (key-binding keys)))
      (when (condition-case err
                  (interactive-form cmd1)
              (error nil))
        (setq cmd2 (ergoemacs-with-major-and-minor-modes
                    (key-binding keys)))
        (unless (eq cmd1 cmd2)
          (setq override cmd1))))
    override))

(defun ergoemacs-shortcut---internal ()
  "Real shortcut function.
This is used for the following functions: `ergoemacs-shortcut-movement'
`ergoemacs-shortcut-movement-no-shift-select' and `ergoemacs-shortcut'.

Basically, this gets the keys called and passes the arguments to`ergoemacs-read-key'."
  (let* ((keys (or ergoemacs-single-command-keys (this-single-command-keys)))
         (args (gethash keys ergoemacs-command-shortcuts-hash))
         (one (nth 0 args)) tmp override)
    (unless args
      (setq keys (read-kbd-macro (key-description keys) t))
      (setq args (gethash keys ergoemacs-command-shortcuts-hash))
      (setq one (nth 0 args)))
    (ergoemacs-read-key keys)
    (setq ergoemacs-single-command-keys nil)))

(defun ergoemacs-shortcut-movement (&optional opt-args)
  "Shortcut for other key/function for movement keys.

This function is `cua-mode' aware for movement and supports
`shift-select-mode'.

Calls the function shortcut key defined in
`ergoemacs-command-shortcuts-hash' for
`ergoemacs-single-command-keys' or `this-single-command-keys'."
  (interactive "^P")
  (ergoemacs-shortcut-movement-no-shift-select opt-args))
(put 'ergoemacs-shortcut-movement 'CUA 'move)

(defun ergoemacs-shortcut-movement-no-shift-select (&optional opt-args)
  "Shortcut for other key/function in movement keys without shift-selection support.

Calls the function shortcut key defined in
`ergoemacs-command-shortcuts-hash' for
`ergoemacs-single-command-keys' or `this-single-command-keys'.
"
  (interactive "P")
  (ergoemacs-shortcut---internal)
  (when (and ergoemacs-mode ergoemacs-repeat-movement-commands
             (called-interactively-p 'any)
             (not cua--rectangle-overlays))
    (set-temporary-overlay-map
     (cond
      ((eq ergoemacs-repeat-movement-commands 'single)
       (unless (where-is-internal last-command (list (intern (concat "ergoemacs-fast-" (symbol-name this-command) "-keymap"))) t)
         (setq ergoemacs-check-mode-line-change (list (intern (concat "ergoemacs-fast-" (symbol-name this-command) "-keymap"))))
         (message (format "Repeat last movement(%s) key: %%s" (symbol-name this-command))
                  (replace-regexp-in-string
                   "M-" "" (key-description (this-single-command-keys))))
         (ergoemacs-mode-line (format " %sSingle" (ergoemacs-unicode-char "↔" "<->"))))
       ,(intern (concat "ergoemacs-fast-" (symbol-name this-command) "-keymap")))
      ((eq ergoemacs-repeat-movement-commands 'all)
       (unless (where-is-internal last-command (list ergoemacs-full-fast-keys-keymap) t)
         (setq ergoemacs-check-mode-line-change (list ergoemacs-full-fast-keys-keymap))
         ;; (message "Repeating movement keys installed")
         (ergoemacs-mode-line (format " %sFull" (ergoemacs-unicode-char "↔" "<->"))))
       ergoemacs-full-fast-keys-keymap)
      (t (intern (concat "ergoemacs-fast-" (symbol-name this-command) "-keymap")))) t)))

(defun ergoemacs-shortcut (&optional opt-args)
  "Shortcut for other key/function for non-movement keys.
Calls the function shortcut key defined in
`ergoemacs-command-shortcuts-hash' for `ergoemacs-single-command-keys' or `this-single-command-keys'."
  (interactive "P")
  (ergoemacs-shortcut---internal))

(defvar ergoemacs-shortcut-send-key nil)
(defvar ergoemacs-shortcut-send-fn nil)
(defvar ergoemacs-shortcut-send-timer nil)

(defvar ergoemacs-debug-shortcuts nil)
(defvar ergoemacs-shortcut-function-binding-hash (make-hash-table :test 'equal))
(defun ergoemacs-shortcut-function-binding (function &optional dont-ignore-menu)
  "Determine the global bindings for FUNCTION.

This also considers archaic emacs bindings by looking at
`ergoemacs-where-is-global-hash' (ie bindings that are no longer
in effect)."
  (let ((ret (gethash (list function dont-ignore-menu) ergoemacs-shortcut-function-binding-hash)))
    (if ret
        (symbol-value 'ret)
      (setq ret (or
                 (if dont-ignore-menu
                     (where-is-internal function (current-global-map))
                   (remove-if
                    '(lambda(x)
                       (or (eq 'menu-bar (elt x 0)))) ; Ignore menu-bar functions
                    (where-is-internal function (current-global-map))))
                 (gethash function ergoemacs-where-is-global-hash)))
      (puthash (list function dont-ignore-menu) ret ergoemacs-shortcut-function-binding-hash)
      (symbol-value 'ret))))

(defcustom ergoemacs-use-function-remapping t
  "Uses function remapping.
For example in `org-agenda-mode' the standard key for
save-buffer (C-x C-s) `org-save-all-org-buffers'"
  :type 'boolean
  :group 'ergoemacs-mode)

(defun ergoemacs-shortcut-remap-list
  (function
   &optional keymap
   ignore-desc dont-swap-for-ergoemacs-functions dont-ignore-commands)
  "Determine the possible current remapping of FUNCTION.

It based on the key bindings bound to the default emacs keys
For the corresponding FUNCTION.

It returns a list of (remapped-function key key-description).

If KEYMAP is non-nil, lookup the binding based on that keymap
instead of the keymap with ergoemacs disabled.

For example, in `org-agenda-mode' C-x C-s runs
`org-save-all-org-buffers' instead of `save-buffer'.

Therefore:

 (ergoemacs-shortcut-remap-list 'save-buffer)

returns

 ((org-save-all-org-buffers [24 19] \"C-x C-s\"))

in `org-agenda-mode'.

If you wish to disable this remapping, you can set
`ergoemacs-use-function-remapping' to nil.

When IGNORE-DESC is t, then ignore key description filters.  When
IGNORE-DESC is nil, then ignore keys that match \"[sAH]-\".  When
IGNORE-DESC is a regular expression, then ignore keys that match
the regular expression.

By default, if an interactive function ergoemacs-X exists, use
that instead of the remapped function.  This can be turned off by
changing DONT-SWAP-FOR-ERGOEMACS-FUNCTIONS.

This command also ignores anything that remaps to FUNCTION,
`ergoemacs-this-command' and
`ergoemacs-shortcut-ignored-functions'.  This can be turned off
by setting changed by setting DONT-IGNORE-COMMANDS to t.

When KEYMAP is defined, `ergoemacs-this-command' is not included
in the ignored commands.

Also this ignores anything that is changed in the global keymap.

If <ergoemacs-user> key is defined, ignore this functional remap.

<ergoemacs-user> key is defined with the `define-key' advice when
running `run-mode-hooks'.  It is a work-around to try to respect
user-defined keys.
"
  (if (not ergoemacs-use-function-remapping) nil
    (let ((key-bindings-lst (ergoemacs-shortcut-function-binding function))
          case-fold-search
          (old-global-map (current-global-map))
          (new-global-map (make-sparse-keymap))
          ret ret2)
      (unwind-protect
          (progn
            (use-global-map new-global-map)
            (when key-bindings-lst
              (mapc
               (lambda(key)
                 (let* (fn
                        (key-desc (key-description key))
                        (user-key
                         (read-kbd-macro
                          (concat "<ergoemacs-user> " key-desc)))
                        fn2)
                   (cond
                    (keymap
                     (setq fn (lookup-key keymap key t))
                     (if (eq fn (lookup-key keymap user-key))
                         (setq fn nil)
                       (unless (condition-case err
                                   (interactive-form fn)
                                 (error nil))
                         (setq fn nil))))
                    (t
                     (ergoemacs-with-global
                      (setq fn (key-binding key t nil (point)))
                      (if (eq fn (key-binding user-key t nil (point)))
                          (setq fn nil)
                        (if (keymapp fn)
                            (setq fn nil))))))
                   (when fn
                     (cond
                      ((eq ignore-desc t))
                      ((eq (type-of ignore-desc) 'string)
                       (when (string-match ignore-desc key-desc)
                         (setq fn nil)))
                      (t
                       (when (string-match "[sAH]-" key-desc)
                         (setq fn nil))))
                     (when fn
                       (unless dont-swap-for-ergoemacs-functions
                         (setq fn2 (condition-case err
                                       (intern-soft (concat "ergoemacs-" (symbol-name fn)))
                                     (error nil)))
                         (when (and fn2 (not (interactive-form fn2)))
                           (setq fn2 nil)))
                       (when (memq fn (append
                                       `(,function ,(if keymap nil ergoemacs-this-command))
                                       ergoemacs-shortcut-ignored-functions))
                         (setq fn nil))
                       (when (and fn2
                                  (memq fn2 (append
                                             `(,function ,(if keymap nil ergoemacs-this-command))
                                             ergoemacs-shortcut-ignored-functions)))
                         (setq fn2 nil))
                       (cond
                        (fn2
                         (push (list fn2 key key-desc) ret2))
                        (fn (push (list fn key key-desc) ret)))))))
               key-bindings-lst)))
        (use-global-map old-global-map))
      (when ret2
        (setq ret (append ret2 ret)))
      (symbol-value 'ret))))

(defun ergoemacs-shortcut-remap (function &optional keys)
  "Runs the FUNCTION or whatever `ergoemacs-shortcut-remap-list' returns.
Will use KEYS or `this-single-command-keys', if cannot find the
original key binding.
"
  (let ((send-keys (or keys (key-description (this-single-command-keys))))
        (fn-lst (ergoemacs-shortcut-remap-list function))
        (fn function)
        send-fn)
    (when fn-lst
      (setq send-keys (nth 2 (nth 0 fn-lst)))
      (setq fn (nth 0 (nth 0 fn-lst))))
    (ergoemacs-read-key-call (or (command-remapping fn (point)) fn))))

(defun ergoemacs-install-shortcuts-map (&optional map dont-complete)
  "Returns a keymap with shortcuts installed.
If MAP is defined, use a copy of that keymap as a basis for the shortcuts.
If MAP is nil, base this on a sparse keymap."
  (let ((ergoemacs-shortcut-override-keymap
         (or map
             (make-sparse-keymap)))
        (ergoemacs-orig-keymap
         (if map
             (copy-keymap map) nil))
        fn-lst)
    (maphash
     (lambda(key args)
       (cond
        ((condition-case err
                 (interactive-form (nth 0 args))
               (error nil))
         (setq fn-lst (ergoemacs-shortcut-remap-list
                       (nth 0 args) ergoemacs-orig-keymap))
         (if fn-lst
             (define-key ergoemacs-shortcut-override-keymap key
               (nth 0 (nth 0 fn-lst)))
           (unless dont-complete
             (define-key ergoemacs-shortcut-override-keymap key
               (nth 0 args)))))
        (t
         (let ((hash (gethash key ergoemacs-command-shortcuts-hash)))
           (cond
            ((not hash) ;; Shouldn't get here
             (define-key ergoemacs-shortcut-override-keymap
               key #'(lambda(&optional arg)
                       (interactive "P")
                       (let (overriding-terminal-local-map
                             overriding-local-map)
                         ;; (setq prefix-arg current-prefix-arg)
                         (condition-case err
                             (call-interactively 'ergoemacs-shortcut)
                           (error (beep) (message "%s" err))))))) 
            ((condition-case err
                 (interactive-form (nth 0 hash))
               (error nil))
             (define-key ergoemacs-shortcut-override-keymap
               key (nth 0 hash)))
            (t
             (define-key ergoemacs-shortcut-override-keymap key
               `(lambda(&optional arg)
                  (interactive "P")
                  (ergoemacs-read-key ,(nth 0 hash) ',(nth 1 hash))))))))))
     ergoemacs-command-shortcuts-hash)
    ;; Now install the rest of the ergoemacs-mode keys
    (unless dont-complete
      (ergoemacs-setup-keys-for-keymap ergoemacs-shortcut-override-keymap)
      ;; Remove bindings for C-c and C-x so that the extract keyboard
      ;; macro will work correctly on links.  (Issue #121)
      (define-key ergoemacs-shortcut-override-keymap (read-kbd-macro "C-c") nil)
      (define-key ergoemacs-shortcut-override-keymap (read-kbd-macro "C-x") nil))
    ergoemacs-shortcut-override-keymap))

(defvar ergoemacs-describe-keybindings-functions
  '(describe-package
    describe-bindings
    describe-key
    where-is
    describe-key-briefly
    describe-function
    describe-variable
    ergoemacs-describe-major-mode)
  "Functions that describe keys.
Setup C-c and C-x keys to be described properly.")

(defvar ergoemacs-show-true-bindings nil
  "Show the true bindings.  Otherwise, show what the bindings translate to...")

(define-minor-mode ergoemacs-shortcut-override-mode
  "Lookup the functions for `ergoemacs-mode' shortcut keys and pretend they are currently bound."
  nil
  :lighter ""
  :global t
  :group 'ergoemacs-mode
  (if ergoemacs-shortcut-override-mode
      (progn
        (let ((x (assq 'ergoemacs-shortcut-override-mode
                       ergoemacs-emulation-mode-map-alist)))
          (when x
            (setq ergoemacs-emulation-mode-map-alist (delq x ergoemacs-emulation-mode-map-alist)))
          ;; Remove shortcuts.
          (setq x (assq 'ergoemacs-shortcut-keys ergoemacs-emulation-mode-map-alist))
          (when x
            (setq ergoemacs-emulation-mode-map-alist (delq x ergoemacs-emulation-mode-map-alist)))
          ;; Create keymap
          (ergoemacs-debug-heading "Turn on `ergoemacs-shortcut-override-mode'")
          (setq ergoemacs-shortcut-override-keymap (ergoemacs-install-shortcuts-map)) 
          (ergoemacs-debug-keymap 'ergoemacs-shortcut-override-keymap)
          (push (cons 'ergoemacs-shortcut-override-mode
                      ergoemacs-shortcut-override-keymap)
                ergoemacs-emulation-mode-map-alist)
          
          (ergoemacs-debug "ergoemacs-emulation-mode-map-alist: %s" (mapcar (lambda(x) (nth 0 x)) ergoemacs-emulation-mode-map-alist))
          (ergoemacs-debug-heading "Finish `ergoemacs-shortcut-override-mode'")
          (ergoemacs-debug-flush)))
    ;; Add back shortcuts.
    (let ((x (assq 'ergoemacs-shortcut-keys ergoemacs-emulation-mode-map-alist)))
      (when x
        (setq ergoemacs-emulation-mode-map-alist (delq x ergoemacs-emulation-mode-map-alist)))
      (push (cons 'ergoemacs-shortcut-keys ergoemacs-shortcut-keymap) ergoemacs-emulation-mode-map-alist))))

(defun ergoemacs-remove-shortcuts ()
  "Removes ergoemacs shortcuts from keymaps."
  (let ((inhibit-read-only t)
        hashkey lookup override-text-map override orig-map)
    (cond
     ((and overriding-terminal-local-map
           (eq saved-overriding-map t))
      (when (or
             (eq (lookup-key
                  overriding-terminal-local-map [ergoemacs]) 'ignore)
             (eq (lookup-key
                  overriding-terminal-local-map [ergoemacs-read]) 'ignore))
        (setq hashkey (md5 (format "override-terminal-orig:%s" overriding-terminal-local-map)))
        (setq lookup (gethash hashkey ergoemacs-extract-map-hash))
        (when lookup
          (setq overriding-terminal-local-map lookup)
          (ergoemacs-debug-heading "Remove ergoemacs from `overriding-terminal-local-map'")
          ;; Save old map.
          (ergoemacs-debug-keymap 'overriding-terminal-local-map))))
     (overriding-local-map
      (when (or (eq (lookup-key overriding-local-map [ergoemacs]) 'ignore)
                (eq (lookup-key overriding-local-map [ergoemacs-read]) 'ignore))
        (setq hashkey (md5 (format "override-local-orig:%s" overriding-local-map)))
        (setq lookup (gethash hashkey ergoemacs-extract-map-hash))
        (when lookup
          (ergoemacs-debug-heading "Remove ergoemacs from `overriding-local-map'")
          (setq overriding-local-map lookup)
          (ergoemacs-debug-keymap 'overriding-local-map))))
     ((progn
        (setq override-text-map (get-char-property (point) 'keymap))
        (and (keymapp override-text-map)
             (or (eq (lookup-key override-text-map [ergoemacs]) 'ignore)
                 (eq (lookup-key override-text-map [ergoemacs-read]) 'ignore))))
      (let ((overlays (overlays-at (point)))
            found)
        (while overlays
          (let* ((overlay (car overlays))
                 (overlay-keymap (overlay-get overlay 'keymap)))
            (if (not (equal overlay-keymap override-text-map))
                (setq overlays (cdr overlays))
              (setq found overlay)
              (setq overlays nil))))
        (setq hashkey (md5 (format "char-map-orig:%s" override-text-map)))
        (setq lookup (gethash hashkey ergoemacs-extract-map-hash))
        (when lookup
          (ergoemacs-debug-heading "Remove ergoemacs from (get-char-property (point) 'keymap)")
          (setq override-text-map lookup)
          (if found
              (overlay-put found 'keymap override-text-map)
            (when (and (previous-single-property-change (point) 'keymap)
                       (next-single-property-change (point) 'keymap))
              (ergoemacs-debug "Put into text properties")
              (put-text-property
               (previous-single-property-change (point) 'keymap)
               (next-single-property-change (point) 'keymap)
               'keymap override-text-map)))
          (ergoemacs-debug-keymap 'override-text-map)))))))

(defun ergoemacs-install-shortcuts-up ()
  "Installs ergoemacs shortcuts into overriding keymaps.
The keymaps are:
- `overriding-terminal-local-map'
- `overriding-local-map'
- overlays with :keymap property
- text property with :keymap property."
  (let ((inhibit-read-only t)
        hashkey hashkey-read lookup override-text-map override-read-map
        override orig-map)
    (cond
     ((and overriding-terminal-local-map
           (eq saved-overriding-map t))
      (when (not
             (eq (lookup-key
                  overriding-terminal-local-map [ergoemacs])
                 'ignore))
        (ergoemacs-debug-heading "Install shortcuts into overriding-terminal-local-map")
        (setq hashkey (md5 (format "override-terminal:%s"
                                   overriding-terminal-local-map)))
        (setq orig-map (copy-keymap overriding-terminal-local-map))
        (setq lookup (gethash hashkey ergoemacs-extract-map-hash))
        (if lookup
            (setq overriding-terminal-local-map lookup) ;; input-keys
          (ergoemacs-install-shortcuts-map overriding-terminal-local-map)
          (setq override-read-map overriding-terminal-local-map)
          (define-key override-read-map [ergoemacs-read] 'ignore)
          ;; Put ergoemacs-read-input-keymap on the current keymap
          (setq overriding-terminal-local-map
                (make-composed-keymap
                 ergoemacs-read-input-keymap overriding-terminal-local-map))
          (define-key overriding-terminal-local-map [ergoemacs] 'ignore)
          ;; Put read-input map in hash for original map and read-map
          (puthash hashkey overriding-terminal-local-map
                   ergoemacs-extract-map-hash)
          (puthash (md5 (format "override-terminal:%s" override-read-map))
                   ergoemacs-extract-map-hash)
          ;; Save old map
          (setq hashkey (md5 (format "override-terminal-orig:%s"
                                     overriding-terminal-local-map)))
          (puthash hashkey orig-map ergoemacs-extract-map-hash)
          ;; Save the keymap without the read-input-keymap
          (puthash (md5
                    (format "override-terminal-read: %s"
                            overriding-terminal-local-map))
                   override-read-map ergoemacs-extract-map-hash))
        (ergoemacs-debug-keymap 'overriding-terminal-local-map)))
     (overriding-local-map
      (when  (not (eq (lookup-key overriding-local-map [ergoemacs])
                      'ignore))
        (ergoemacs-debug-heading "Install shortcuts into overriding-local-map")
        (setq hashkey (md5 (format "override-local:%s"
                                   overriding-local-map)))
        (setq orig-map (copy-keymap overriding-local-map))
        (setq lookup (gethash hashkey ergoemacs-extract-map-hash))
        (if lookup
            (setq overriding-local-map lookup)
          (ergoemacs-debug-keymap orig-map)
          (ergoemacs-install-shortcuts-map overriding-local-map)
          (setq override-read-map overriding-terminal-local-map) ;; Read map
          (define-key override-read-map [ergoemas-read] 'ignore)
          (ergoemacs-debug-keymap override-read-map)
          (setq overriding-local-map
                (make-composed-keymap
                 ergoemacs-read-input-keymap overriding-local-map)) ;; read-input-keymap
          (define-key overriding-local-map [ergoemacs] 'ignore)
          (ergoemacs-debug-keymap overriding-local-map)
          (puthash hashkey overriding-local-map ergoemacs-extract-map-hash)
          (puthash (md5 (format "override-local:%s"
                                overriding-read-map)) overriding-local-map ergoemacs-extract-map-hash)
          ;; Save old map.
          (puthash (md5
                    (format "override-local-read: %s"
                            overriding-local-map))
                   override-read-map ergoemacs-extract-map-hash)
          (puthash (md5 (format "override-local-orig:%s"
                                overriding-local-map)) orig-map ergoemacs-extract-map-hash)
          (puthash (md5 (format "override-local-orig:%s"
                                override-read-map)) orig-map ergoemacs-extract-map-hash))
        (ergoemacs-debug-keymap 'overriding-local-map)))
     ((progn
        (setq override-text-map (get-char-property (point) 'keymap))
        (and (keymapp override-text-map)
             (not (eq (lookup-key override-text-map [ergoemacs])
                      'ignore))))
      (ergoemacs-debug-heading "Install shortcuts into (get-char-property (point) 'keymap)")
      (let ((overlays (overlays-at (point)))
            found)
        (while overlays
          (let* ((overlay (car overlays))
                 (overlay-keymap (overlay-get overlay 'keymap)))
            (if (not (equal overlay-keymap override-text-map))
                (setq overlays (cdr overlays))
              (setq found overlay)
              (setq overlays nil))))
        (setq hashkey (md5 (format "char-map:%s" override-text-map)))
        (setq orig-map (copy-keymap override-text-map))
        (setq lookup (gethash hashkey ergoemacs-extract-map-hash))
        (if lookup
            (progn
              (setq override-text-map lookup))
          (ergoemacs-install-shortcuts-map override-text-map t)
          (setq override-read-map (copy-keymap override-text-map))
          (define-key override-read-map [ergoemacs-read] 'ignore)
          (setq override-text-map
                (copy-keymap
                 (make-composed-keymap
                  (list ergoemacs-read-input-keymap override-text-map))))
          
          (define-key override-text-map [ergoemacs] 'ignore)
          (puthash hashkey override-text-map ergoemacs-extract-map-hash)
          (puthash (md5 (format "char-map:%s" override-read-map)) override-text-map ergoemacs-extract-map-hash)
          ;; Save old map.
          
          ;; Lookup map on either the composed or non-composed map
          ;; gives the same original map
          (setq hashkey (md5 (format "char-map-orig:%s" override-text-map)))
          (puthash hashkey orig-map ergoemacs-extract-map-hash)
          (setq hashkey (md5 (format "char-map-orig:%s" override-read-map)))
          (puthash hashkey orig-map ergoemacs-extract-map-hash)
          (setq hashkey (md5 (format "char-map-read:%s" override-text-map)))
          (puthash hashkey override-read-map ergoemacs-extract-map-hash)
          (setq hashkey (md5 (format "char-map-read:%s" override-read-map)))
          (puthash hashkey override-read-map ergoemacs-extract-map-hash))
        (if found
            (overlay-put found 'keymap override-text-map)
          ;; Overlay not found; change text property
          (ergoemacs-debug "Put into text properties")
          (put-text-property
           (previous-single-property-change (point) 'keymap)
           (next-single-property-change (point) 'keymap)
           'keymap
           override-text-map))
        (ergoemacs-debug-keymap 'override-text-map))))))

(provide 'ergoemacs-shortcuts)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ergoemacs-shortcuts.el ends here
