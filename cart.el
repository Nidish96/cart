(defcustom cart--XY_0sl '((X . (0.0 1.0))
			(Y . (0.0 1.0)))
  "These are the calibration values"
  :group 'cart)

(defcustom cart-keymap-prefix "C-x a"
  "The prefix for cart-mode key bindings"
  :type 'string
  :group 'cart)

(defun cart--key (key)
  (kbd (concat cart-keymap-prefix " " key)))

(define-minor-mode cart-mode
  "Automatic inteRactive coordinates for Tikz"
  nil
  :global nil
  :group 'cart
  :lighter " cart"
  :keymap
  (list (cons (cart--key "c") #'cart-calibrate)
	(cons (cart--key "p") #'cart-insert-point)
	(cons (cart--key "d") #'cart-tikz-draw)
	(cons (cart--key "n") #'cart-tikz-node))

  (if cart-mode
      (message "cart-mode activated!")
    (message "cart-mode de-activated!"))

  (add-hook 'cart-mode-hook (lambda () (message "cart mode hook was execd")))
  (add-hook 'cart-mode-on-hook (lambda () (message "cart mode hook was execd on")))
  (add-hook 'cart-mode-off-hook (lambda () (message "cart mode hook was execd off"))))

(defun cart--gmc (&optional prompt)
  "Returns the xy points of clicked point (if clicked) as a cons block"
  (let* ((event (read-event (or prompt "Click anywhere"))))
    (if (string-equal (car-or event) "down-mouse-1")
	(progn
	  (read-event)  ;; read the mouse up event
	  (setq pos (event-start event))
	  (setq xy (posn-x-y pos))
	  (mapcar 'float (list (car xy) (cdr xy)))))))

(defun cart--2dc (&optional prompt)
  "Returns 2D coordinates as a cons block"
  (interactive)
  (let ((x (float (read-number (format "(%s): Enter X coordinate: " prompt) 0)))
	(y (float (read-number (format "(%s): Enter Y coordinate: " prompt) 0))))
    (list x y)))

(defun cart--xy2x0sl (x y)
  "Convert list of x and y points to x0 (intercept) and sl (slope)"
  (let ((x1 (elt x 0))
	(x2 (elt x 1))
	(y1 (elt y 0))
	(y2 (elt y 1)))
    (setq x0 (/ (- (* x1 y2) (* x2 y1)) (- x1 x2)))
    (setq sl (/ (- y1 y2) (- x1 x2)))
    (list x0 sl)))

(defun cart-calibrate ()
  "Conduct calibration to set the cart--XY_0sl variable"
  (interactive)
  (let* ((XY1 (cart--2dc "Point 1"))
	 (xy1 (save-excursion (cart--gmc "Click on Point 1")))
	 (XY2 (cart--2dc "Point 2"))
	 (xy2 (save-excursion (cart--gmc "Click on Point 2"))))
    (setq Xs (mapcar #'(lambda (x) (elt x 0)) (list XY1 XY2)))
    (setq Ys (mapcar #'(lambda (x) (elt x 1)) (list XY1 XY2)))
    (setq xs (mapcar #'(lambda (x) (elt x 0)) (list xy1 xy2)))
    (setq ys (mapcar #'(lambda (x) (elt x 1)) (list xy1 xy2)))
    (setq X_0sl (cart--xy2x0sl Xs xs))
    (setq Y_0sl (cart--xy2x0sl Ys ys))
    (setf (alist-get 'X cart--XY_0sl) X_0sl)
    (setf (alist-get 'Y cart--XY_0sl) Y_0sl)
    (list XY1 XY2 xy1 xy2)
    ))

(defun cart/XY2xy (XY)
  "Transform point from pixels to calibrated coordinate system"
  (list
   (/ (- (elt XY 0) (elt (alist-get 'X cart--XY_0sl) 0)) (elt (alist-get 'X cart--XY_0sl) 1))
   (/ (- (elt XY 1) (elt (alist-get 'Y cart--XY_0sl) 0)) (elt (alist-get 'Y cart--XY_0sl) 1))))

(defun cart-insert-point ()
  "Query point and insert coordinates"
  (interactive)
  (let ((XY (cart--gmc "Click on Point")))
    (message "%s" XY)
    (if XY (progn
             (setq xy (cart/XY2xy XY))
             (insert (format "(%f, %f)" (elt xy 0) (elt xy 1)))
             xy))))

(defun cart--optbr (&optional opts)
  (if (not (string-empty-p opts))
      (format "[%s]" opts)
    opts))

(defun cart-tikz-draw (&optional dopts nopts)
  "Initiate a tikz \draw instance and insert points sequentially as user clicks"
  (interactive "sDraw options: \nsNode options: ")
  (insert (format "\\draw%s " (cart--optbr dopts)))
  (while (cart-insert-point)
    (insert (format "%s -- " nopts)))
  (delete-backward-char 4)
  (insert ";\n"))

(defun cart-tikz-node (&optional nopts nval)
  "Initiate a tikz \node instance and insert value given by user"
  (interactive "sNode options: \nsNode value: ")
  (insert (format "\\node%s at " (cart--optbr nopts)))
  (cart-insert-point)
  (insert (format " \{%s\};\n" nval)))

(defun cart--last-open-paren (&optional pos)
  "Returns the last open paren that the current point lies in.
Optional argument POS allows user to specify point (other that current).

Code from this stackoverflow answer: https://emacs.stackexchange.com/a/10405"
  (let ((ppss (syntax-ppss (or pos (point)))))
    (when (nth 1 ppss) (char-after (nth 1 ppss)))))

(defun cart--translate (&optional dx dy)
  "Conduct rigid body movement on current object.
DX, DY are x (horizontal) and y (vertical translation.

BUG: sentence doesn't seem to mean what we expected.
Do we want to include rotations also?"
  (search-forward ")")
  (let ((ptst (beginning-of-thing 'sentence))
        (pten (save-excursion (end-of-thing 'sentence))))
    (while (setq p0 (search-forward "(" pten t))
      (if (cart--last-open-paren (1- p0))
          (goto-char (1+ (point)))
        (setq p1 (1- (search-forward ")" pten)))
        (setq cds
              (mapcar 'string-to-number
                      (split-string
                       (buffer-substring p0 p1) ",")))
        (delete-region p0 p1)
        (goto-char p0)
        (setf (elt cds 0) (+ (elt cds 0) (or dx 0)))
        (setf (elt cds 1) (+ (elt cds 1) (or dy 0)))
        (insert (mapconcat 'number-to-string cds ","))
        (setq pten (save-excursion (end-of-thing 'sentence)))))))

(defun cart-move-object ()
  "Move objects in current sentence or under region using two points."
  (interactive)
  (let ((xy0 (cart/XY2xy (cart--gmc "Click on reference point")))
        (xy1 (cart/XY2xy (cart--gmc "Click on target point"))))
    (setq dx (- (elt xy0 0) (elt xy1 0)))
    (setq dy (- (elt xy0 1) (elt xy1 1)))

    (if (region-active-p)
        (message "gotta check all sentences in region")
      (cart--translate dx dy))))

(provide 'cart)
