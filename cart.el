;;; cart.el --- CAlibrated inteRactive coordinates for Tikz       -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Nidish Narayanaa Balaji

;; Author: Nidish Narayanaa Balaji <nidbid@gmail.com>
;; Keywords: tex, mouse
;; Version: 0.0.1
;; Package-Requires: ((emacs "25.1"))
;; URL: https://github.com/Nidish96/cart.el

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; cart.el provides convenient function definitions meant to be used
;; in tandem with auctex and some pdf viewer within emacs (like
;; pdf-tools). The main purpose is to speed up inserting and editing
;; graphical objects using Tikz/Pgf on latex documents/(beamer)
;; presentations.

;; So far there is support for inserting Tikz draw and
;; node objects, and conducting rigid body translations and
;; rotations on these objects. The way to use this would be to first
;; calibrate the coordinate system by clicking on two points and
;; providing their coordinate values. This allows the package to
;; establish the coordinate mapping between the pixel coordinates on
;; the frame to the Tikz/Pgf coordinates meant to be inputted. The
;; relevant calibration variable is customizable. So after a
;; particular calibration, if the user feels that the same view can be
;; used across sessions, then it may be saved in the customize
;; interface. See more in the README.org file.

;;; Code:

(defcustom cart--XY_0sl '((X . (0.0 1.0))
                        (Y . (0.0 1.0)))
  "These are the calibration values. The behavior will be identical across sessions if these are saved."
  :group 'cart)

(defcustom cart-keymap-prefix "C-x a"
  "The prefix for cart-mode key bindings."
  :type 'string
  :group 'cart)

(defun cart--key (key)
  "A function to define a cart.el key binding along with the keymap prefix above."
  (kbd (concat cart-keymap-prefix " " key)))

(define-minor-mode cart-mode
  "CAlibrated inteRactive coordinates for Tikz"
  :global nil
  :group 'cart
  :lighter " cart"
  :keymap
  (list (cons (cart--key "c") #'cart-calibrate)
        (cons (cart--key "p") #'cart-insert-point)
        (cons (cart--key "d") #'cart-tikz-draw)
        (cons (cart--key "n") #'cart-tikz-node)
        (cons (cart--key "t") #'cart-translate-tikz)
        (cons (cart--key "r") #'cart-rotate-tikz)))

(defun cart--gmc (&optional prompt)
  "Prompts the user to click on the frame and returns the xy coordinates. Two behaviors are possible:
(if clicked) single point returned as a list with the two coordinates;
(if dragged) start and end points of dragged region returned as a list of two point-lists (as above). 

The optional parameter PROMPT allows one to specify a user-facing prompt. The prompt defaults to 'Click anywhere' if not provided."
  (if (string-equal (car-or (read-event (or prompt "Click anywhere"))) "down-mouse-1")
      (let* ((event (read-event))  ;; read the mouse up/drag event
             (pos (event-start event))
             (pose (event-end event))
             (xy (posn-x-y pos))
             (xye (posn-x-y pose)))
        (if (eq pos pose)
            (mapcar 'float (list (car xy) (cdr xy)))
          (list (mapcar 'float (list (car xy) (cdr xy)))
                (mapcar 'float (list (car xye) (cdr xye))))))))

(defun cart--2dc (&optional prompt)
  "Prompts the user to enter the X and Y coordinates in their drawing coordinate system and returns the 2D coordinates as a list. The user is prompted with the string \"(PROMPT): Enter Q coordinate: \" where Q is (X,Y) and PROMPT is an optional parameter.
"
  (interactive)
  (let ((x (float (read-number (format "(%s): Enter X coordinate: " (or prompt "")) 0)))
        (y (float (read-number (format "(%s): Enter Y coordinate: " (or prompt "")) 0))))
    (list x y)))

(defun cart--xy2x0sl (x y)
  "Convert list of x and y points to x0 (intercept) and sl (slope).

The two parameters, X & Y, are lists of two numbers storing the x and y values of two points respectively."
  (let* ((x1 (elt x 0))
         (x2 (elt x 1))
         (y1 (elt y 0))
         (y2 (elt y 1))
         (x0 (/ (- (* x1 y2) (* x2 y1)) (- x1 x2)))
         (sl (/ (- y1 y2) (- x1 x2))))
    (list x0 sl)))

(defun cart-calibrate ()
  "Conduct interactive calibration to set the cart--XY_0sl variable."
  (interactive)
  (let* ((XY1 (cart--2dc "Point 1"))
         (xy1 (save-excursion (cart--gmc "Click on Point 1")))
         (XY2 (cart--2dc "Point 2"))
         (xy2 (save-excursion (cart--gmc "Click on Point 2")))
         (Xs (mapcar #'(lambda (x) (elt x 0)) (list XY1 XY2)))
         (Ys (mapcar #'(lambda (x) (elt x 1)) (list XY1 XY2)))
         (xs (mapcar #'(lambda (x) (elt x 0)) (list xy1 xy2)))
         (ys (mapcar #'(lambda (x) (elt x 1)) (list xy1 xy2)))
         (X_0sl (cart--xy2x0sl Xs xs))
         (Y_0sl (cart--xy2x0sl Ys ys)))
    (setf (alist-get 'X cart--XY_0sl) X_0sl)
    (setf (alist-get 'Y cart--XY_0sl) Y_0sl)
    (list XY1 XY2 xy1 xy2)))

(defun cart--XY2xy (XY)
  "Transform point from pixels to calibrated coordinate system.

Input parameter XY is a list of two values storing the coordinates."
  (list
   (/ (- (elt XY 0) (elt (alist-get 'X cart--XY_0sl) 0)) (elt (alist-get 'X cart--XY_0sl) 1))
   (/ (- (elt XY 1) (elt (alist-get 'Y cart--XY_0sl) 0)) (elt (alist-get 'Y cart--XY_0sl) 1))))

(defun cart-insert-point (&optional prompt)
  "Query the user to click on a point and insert its corresponding coordinates as \"(x, y)\" at the current point.

Optional input parameter PROMPT allows setting the user-facing prompt. Defaults to \"Click on Point\"."
  (interactive)
  (let ((XY (cart--gmc prompt)))
    (if XY (let ((xy (cart--XY2xy XY)))
             (insert (format "(%f, %f)" (elt xy 0) (elt xy 1)))
             xy))))

(defun cart--optbr (&optional opts)
  "Insert options bounded by square braces if provided options OPTS is non-nil. If nil, do nothing.

Optional input parameter OPTS is either a string of ooptions or nil."
  (if (not (string-empty-p opts))
      (format "[%s]" opts)
    opts))

(defun cart-tikz-draw (&optional dopts nopts)
  "Initiate a tikz \draw instance and insert points sequentially as user clicks, after prompting the user for draw options and common node options (added after each point). Format for the insertion is:
        \draw[DOPTS] (x1, y1) NOPTS -- (x2, y2) NOPTS -- (x3, y3) NOPTS -- ...;
Note that the \"node options\" NOPTS is not bounded by square braces. The user will have to type them in explicitly if needed.
The user hits RET to finish inserting points. Finally a prompt shows up checking if the user wants the first point inserted in the end again (to make the diagram loop itself.

Optional input parameters DOPTS and NOPTS are strings of draw and node options respectively. The user receives prompts for populating these.
"
  (interactive "sDraw options: \nsNode options: ")
  (insert (format "\\draw%s " (cart--optbr dopts)))
  (while (cart-insert-point "Click on a point (RET to stop insertion)")
    (insert (format "%s -- " nopts)))
  (if (y-or-n-p "Insert first point at the end?")
      (progn
        (cart--goto-begend)
        (search-forward "(")
        (while (cart--last-open-paren (1- (point)))
          (search-forward "("))
        (let ((pt1 (buffer-substring (point) (save-excursion (search-forward ")")))))
          (move-end-of-line nil)
          (insert (format "%s" pt1))))
    (delete-backward-char 4))
  (insert ";")
  (do-auto-fill))

(defun cart-tikz-node (&optional nopts nval)
  "Initiate a tikz \node instance and insert value given by user, after prompting the user for node options and node value. Similar in functionality to cart-tikz-draw except this has exactly only point. Format for the insertion is:
        \node[NOPTS] at (x, y) {NVAL};

Optional input parameters NOPTS and NVAL and the strings containing the node options and node value respectively. 
"
  (interactive "sNode options: \nsNode value: ")
  (insert (format "\\node%s at " (cart--optbr nopts)))
  (cart-insert-point)
  (insert (format " \{%s\};" nval))
  (do-auto-fill))

(defun cart--last-open-paren (&optional pos)
  "Returns the last open paren that the current point lies in.

Optional input parameter POS allows user to specify point (defaults to \"(point)\").

Code originally from this stackoverflow answer: https://emacs.stackexchange.com/a/10405"
  (let ((ppss (syntax-ppss (or pos (point)))))
    (when (nth 1 ppss) (char-after (nth 1 ppss)))))

(defun cart--goto-begend (&optional enflg)
  "Moves pointer to either the beginning or the end of the current Tikz statement (assumed to start with a \"\\\" and end with a \";\".

Optional input parameter ENFLG controls behavior.
If nil, point is moved to beginning.
If non-nil, point is moved to end."
  (if enflg
      (while (cart--last-open-paren (search-forward ";" nil t)))
    (while (cart--last-open-paren (search-backward "\\" nil t))))
  (point))

(defun cart--angle (vec1 vec2)
  "Returns the angle between the two vectors (given as lists) in radians (domain [0,2pi)).

Input parameters VEC1 and VEC2 are two-number-lists storing the x and y components of the vectors."
  (let ((Cth (+ (* (elt vec1 0) (elt vec2 0)) (* (elt vec1 1) (elt vec2 1))))
        (Sth (- (* (elt vec1 0) (elt vec2 1)) (* (elt vec2 0) (elt vec1 1)))))
    (atan Sth Cth)))

(defun cart--translate (&optional dx dy) 
  "Conduct rigid body translation on current context (generated through narrow). It is important for context to start from the first object's \"\\\" character and end at the last object's \";\" character.

Optional input parameters DX, DY are x (horizontal) and y (vertical) translation values."
  (goto-char (point-min))
  (let ((p0) (p1) (cds))
    (while (setq p0 (search-forward "(" (point-max) t))
      (if (cart--last-open-paren (1- p0))
          (goto-char (1+ (point)))
        (setq p1 (1- (search-forward ")")))
        (setq cds
              (mapcar 'string-to-number
                      (split-string
                       (replace-regexp-in-string
                        "\n" "" (buffer-substring p0 p1))
                       ",")))
        (delete-region p0 p1)
        (goto-char p0)
        (setf (elt cds 0) (+ (elt cds 0) (or dx 0)))
        (setf (elt cds 1) (+ (elt cds 1) (or dy 0)))
        (insert (mapconcat 'number-to-string cds ","))))))

(defun cart--rotate (&optional tht cpt rnds) 
  "Conduct rigid body rotation on current context (generated through narrow). It is important for context to start from the first object's \"\\\" character and end at the last object's \";\" character.

Optional input parameters control the amount/type of rotations.
THT is rotation angle;
CPT is a list storing center point coordinates; and
RNDS is a boolean governing whether node contents should be rotated or not."
  (goto-char (point-min))
  (let ((p0) (p1) (cds))
    (while (setq p0 (search-forward "(" (point-max) t))
      (if (cart--last-open-paren (1- p0))
          (goto-char (1+ (point)))
        (setq p1 (1- (search-forward ")")))
        (setq cds
              (mapcar 'string-to-number
                      (split-string
                       (replace-regexp-in-string
                        "\n" "" (buffer-substring p0 p1))
                       ",")))
        (delete-region p0 p1)
        (goto-char p0)
        ;; Relative coordinates & Rotation
        (let* ((cdsrel (list (- (elt cds 0) (or (elt cpt 0) 0))
                             (- (elt cds 1) (or (elt cpt 1) 0))))
               (Cth (cos (or tht 0)))
               (Sth (sin (or tht 0)))
               (Tcds (list (+ (- (* Cth (elt cdsrel 0)) (* Sth (elt cdsrel 1))) (or (elt cpt 0) 0))
                           (+ (+ (* Sth (elt cdsrel 0)) (* Cth (elt cdsrel 1))) (or (elt cpt 1) 0)))))
          (insert (mapconcat 'number-to-string Tcds ","))))))
  ;; Rotate nodes too, if needed
  (when rnds
    (goto-char (point-min))
    (while (search-forward "node" nil t)
      (unless (cart--last-open-paren)
        (if (not (eq (char-after) (string-to-char "[")))
            (insert (format "[rotate=%f]" (radians-to-degrees tht)))
          (let ((ebr (save-excursion (search-forward "]"))))
            (if (search-forward "rotate" ebr t)
                (progn
                  (right-word)
                  (let ((nwang (+ (number-at-point) (radians-to-degrees tht))))
                    (skip-chars-backward "0-9.-")
                    (delete-region (point) (progn (skip-chars-forward "0-9.-") (point)))
                    (insert (format "%f" nwang)))
                  (goto-char ebr))
              (goto-char (1- ebr))
              (insert (format ", rotate=%f" (radians-to-degrees tht))))))))))

(defun cart-translate-tikz ()
  "Translate objects in current Tikz/Pgf statement (bound by \"\\\", \";\") or under region using two points. This works by first calling narrow-to-region, followed by a call to cart--translate.
If a region is not chosen, the current statement (bound by \"\\\", \";\") is used for the narrow.
If a region is chose, the region is used for the narrow. It is important for the region to start from the first object's \"\\\" character and end at the last object's \";\" character.

The user is queried to click & drag from the start point to end point representing the desired translation. If the user does not drag and instead, just clicks, a prompt is launched asking the user to click on trget point.
"
  (interactive)
  (let* ((XYs (cart--gmc "Click & drag from start point to end point"))
         (XY0 (elt XYs 0))
         (XY1 (elt XYs 1)))
    (unless (listp XY0)
      (setq XY0 XYs)
      (setq XY1 (cart--gmc "You had only clicked on one point. Please click target point now")))

    (let* ((xy0 (cart--XY2xy XY0))
           (xy1 (cart--XY2xy XY1))
           (dx (- (elt xy1 0) (elt xy0 0)))
           (dy (- (elt xy1 1) (elt xy0 1))))

      (if (region-active-p)
          (narrow-to-region (region-beginning) (region-end))
        (narrow-to-region (cart--goto-begend) (cart--goto-begend t)))

      (cart--translate dx dy)
      (goto-char (point-min))
      (while (not (eobp))
        (move-end-of-line nil)
        (do-auto-fill)
        (forward-line))
      (do-auto-fill)
      (widen))))

(defun cart-rotate-tikz ()
  "Rotate objects in current Tikz/Pgf statement (bound by \"\\\", \";\") or under region using two points. This works by first calling narrow-to-region, followed by a call to cart--translate.
If a region is not chosen, the current statement (bound by \"\\\", \";\") is used for the narrow.
If a region is chose, the region is used for the narrow. It is important for the region to start from the first object's \"\\\" character and end at the last object's \";\" character.

The user is prompted to click on the center of rotation, then to click and drag the rotation target points. The angle of rotation is calculated as the angle between the vectors joining the center point with the end-points of the drag operation. If the user fails to drag, another prompt is launched asking the user to click on the target point.

After the coordinate values are modified, the user is prompted to say whether the node contents must be rotated too or not. The \"rotate\" field of the nodes (which comes in Tikz/Pgf) is used for this. If no options are present for a node, \"[rotate=THT]\" is inserted (where THT is the angle in degrees). If options are present for a node, and a rotate field already exists, the existing value is replaced by its sum with THT. If options are present for a node, and no rotate field exists, it is inserted. 
"
  (interactive)
  (let* ((XYref (cart--gmc "Click on the center of rotation (RET to use origin) "))
         (XYs (cart--gmc "Click and drag the rotation target points "))
         (rnds (y-or-n-p "Rotate Node contents too?"))
         (XY0 (elt XYs 0))
         (XY1 (elt XYs 1))
         (xyref (if XYref (cart--XY2xy XYref) (list 0 0))))
    (unless (listp XY0)
      (setq XY0 XYs)
      (setq XY1 (cart--gmc "You had only clicked on one point. Please click target point now")))

    (let* ((xy0 (cart--XY2xy XY0))
           (xy1 (cart--XY2xy XY1))
           ;; Relative Coordinates
           (xy0 (list (- (elt xy0 0) (elt xyref 0)) (- (elt xy0 1) (elt xyref 1))))
           (xy1 (list (- (elt xy1 0) (elt xyref 0)) (- (elt xy1 1) (elt xyref 1))))
           (theta (cart--angle xy0 xy1)))

      (if (region-active-p)
          (narrow-to-region (region-beginning) (region-end))
        (narrow-to-region (cart--goto-begend) (cart--goto-begend t)))

      (cart--rotate theta xyref rnds)
      (goto-char (point-min))
      (while (not (eobp))
        (move-end-of-line nil)
        (do-auto-fill)
        (forward-line))
      (do-auto-fill)
      (widen))))

(provide 'cart)
;;; cart.el ends here
