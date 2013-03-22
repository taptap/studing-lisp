;;; Define package
(defpackage :cl-fractals
  (:use :ltk :cl))

(in-package :cl-fractals)

;;; Virtual machine

#|

(defclass l-machine ()
  ((rules :accessor rules
	  :initform nil
	  :initarg :rules)
   (axiom :accessor axiom
	  :initform ""
	  :initarg :axiom)
   (angle :accessor angle
	  :initform 360/6
	  :initarg :angle)
   (depth :accessor depth
	  :initform 0
	  :initarg :depth)))
|#

(defvar *rules*)
(setf *rules* nil)

(defvar *axiom*)
(setf *axiom* "")

(defvar *depth*)
(setf *depth* 0)

(defvar *angle*)
(setf *angle* 12)

(defun parse-rule-multi (text)
  (labels ((accum-key (rlist accum)
	   (if (and (equal (car rlist) #\-)
		    (equal (cadr rlist) #\>))
	       (cons accum (accum-value (cddr rlist) nil))
	       (accum-key (cdr rlist)
			  (append accum (list (car rlist))))))
	   
	   (accum-value (rlist accum)
	     (if rlist (accum-value (cdr rlist)
				    (append accum (list (car rlist))))
		 accum)))
    (accum-key (coerce text 'list) nil)))

(defun parse-rule (text)
  (labels ((accum-value (rlist accum)
	     (if rlist (accum-value (cdr rlist)
				    (append accum (list (car rlist))))
		 accum)))
    (let ((ctext (coerce text 'list)))
      (cons (car ctext) (accum-value (cdddr ctext) nil)))))

(defun add-rule (text)
  (setf *rules* (cons (parse-rule text) *rules*)))

(defun del-rule (number)
  (setf *rules* (remove (nth number *rules*) *rules* :test #'equal)))

(defun set-axiom (text)
  (setf *axiom* text))

(defun set-depth (num)
  (setf *depth* num))


(defun print-contents ()
  (format t "rules: ~{~a~^, ~}~%axiom: ~a~%depth: ~a~%" *rules* *axiom* *depth*))

(defvar *canvas-width* 800)
(defvar *canvas-height* 600)

(defvar *x*)
(setf *x* (/ *canvas-width* 2))

(defvar *y*)
(setf *y* (/ *canvas-height* 2))

(defvar *a*)
(setf *a* 0.0)

(defvar *stack*)
(setf *stack* nil)

(defvar *len*)
(setf *len* 4)

(defstruct state x y a)

(defun plot-fractal (c)
  (labels ((rec-plot (cur-depth depth current-string c)
	     (if current-string
		 ;; recursing down
		 (if (and (< cur-depth depth)
			  (assoc (car current-string) *rules*))
		     (progn 
		       (rec-plot (+ 1 cur-depth)
				 depth
				 (cdr (assoc (car current-string) *rules*))
				 c)
		       (rec-plot cur-depth depth (cdr current-string) c))
		     (progn 
		       (cond ((equal (car current-string) #\F)
			      (create-line c (list *x* *y* 
					       (+ *x* (* *len* (cos *a*)))
					       (+ *y* (* *len* (sin *a*)))))
			      (setf *x* (+ *x* (* *len* (cos *a*))))
			      (setf *y* (+ *y* (* *len* (sin *a*)))))
		
			     ((equal (car current-string) #\-) 
			      (setf *a* (- *a* (/ (* 2 pi) *angle*))))
			     
			     ((equal (car current-string) #\+)
			      (setf *a* (+ *a* (/ (* 2 pi) *angle*))))
			     
			     ((equal (car current-string) #\[)
			      (setf *stack*
				    (cons (make-state :x *x* :y *y* :a *a*)
					  *stack*)))
			     
			     ((equal (car current-string) #\])
			      (setf *a* (state-a (car *stack*)))
			      (setf *x* (state-x (car *stack*)))
			      (setf *y* (state-y (car *stack*)))
			      (setf *stack* (cdr *stack*))))

		       (rec-plot cur-depth depth (cdr current-string) c))))))

    (print-contents)
    (rec-plot 0 *depth* (coerce *axiom* 'list) c)))
		     
;;; View 

(defun create-window ()
  (with-ltk ()
    (let* ((c (make-instance 'canvas			
			     :width *canvas-width*
     			     :height *canvas-height*))
	   (axi (make-instance 'entry :text "FXF--FF--FF"))
	   (f (make-instance 'frame :relief :groove :borderwidth 2))
	   (lb (make-instance 'listbox :master f))
	   (scrll (make-instance 'scrollbar :orientation :vertical :master f))
	   (rul (make-instance 'entry :text "->"))
	   (add (make-instance 'button :text "Add"
			       :command (lambda ()
					  (let ((txt (text rul)))
					    (listbox-append lb txt)
					    (add-rule txt)))))
	   (del (make-instance 'button :text "Delete"
			       :command (lambda ()
					  (let ((sel (car (listbox-get-selection lb))))
					    (if sel 
						(progn
						  (del-rule sel)
						  (listbox-delete lb sel)
						  (cond ((> 0 (- sel 1)) (listbox-select lb sel))
							(t (listbox-select lb (- sel 1))))))))))
	   (dpth (make-instance 'entry :text "4"))
	   (plot (make-instance 'button :text "Plot" 
				:command (lambda ()
					   (set-axiom (text axi))
					   (set-depth (read-from-string (text dpth)))
					   (plot-fractal c))))
	   (quit (make-instance 'button :text "Quit" 
				:command (lambda ()
					   (setf *exit-mainloop* t)))))
      ;; add scrollbar to listbox
      (configure scrll "command" (concatenate 'string (widget-path lb) " yview"))
      (configure lb "yscrollcommand" (concatenate 'string (widget-path scrll) " set"))
      ;; canvas and theorem entry
      (grid c 0 0 :rowspan 6 :sticky "ns" :padx 4 :pady 4)
      (grid axi 0 1 :columnspan 2 :padx 4 :sticky "we" :pady 2)
      ;; frame with rules list and a scrollbar
      (grid f 1 1 :columnspan 2)
      (pack scrll :side :right :fill :y)
      (pack lb :side :left)
      ;; remaining widgets
      (grid rul 2 1 :sticky "we" :columnspan 2 :padx 4 :pady 2)
      (grid add 3 1 :sticky "we")
      (grid del 3 2 :sticky "we")
      (grid dpth 4 1 :columnspan 2 :padx 4 :sticky "we" :pady 2)
      (grid plot 5 1 :sticky "we")
      (grid quit 5 2 :sticky "we")
      ;; initialize canvas
      (configure c :background "white")
      (create-rectangle c 1 1 *canvas-width* *canvas-height*))))
