; scuffle.lisp
; A scrabble solver written in Common Lisp.
;
; Copyright Oliver C. Sandli <oliversandli@icloud.com> 2021

(ql:quickload :snakes)


; CONVERSION FUNCTIONS
(defun string-to-list (s)
  (coerce s 'list))

(defun list-to-string (l)
  ; `format' or `coerce' works.
  ; `coerce' is used here for continuity with `string-to-list'.
  ; (format nil "~{~A~}" l))
  (coerce l 'string))


; BOARD FUNCTIONS
(defun create-board (size start-val)
  (loop repeat size collect (loop repeat size collect start-val)))

(defun set-2d-l-e (a e i)
  "modify `a' based on the values in `e' and the indexes in `i'"
  (setq e (string-to-list e))
  (loop for x in i
        for y in e do
        (setf (nth (cadr x) (nth (car x) a)) y))
  nil)

(defun nth-nth (l yx)
  "get the index `y' (row), `x' (column) of 2D list `l'"
  (or (nth (cadr yx) (nth (car yx) l)) 'out-of-bounds-error))

(defun get-col (b x)
  "get column `x' of 2D list `b'"
  (mapcar (lambda (r) (nth x r)) b))

(defun by-cols (b)
  "return a list of columns of 2D list `b'"
  (let ((width (length (car b))))
    (loop for w from 0 below width collect
          (get-col b w))))

(defun coord-range (start end)
  "find all values between and including start and end"
  (if (= (car start) (car end))
    (mapcar (lambda (x) (list (car start) x)) (loop for i from (cadr start) to (cadr end) collect i))
    (mapcar (lambda (x) (list x (cadr start))) (loop for i from (car start) to (car end) collect i))))


; SCORING FUNCTIONS
(defun create-map (file-name)
  (mapcar (lambda (c) (mapcar 'parse-integer (uiop:split-string c))) (uiop:read-file-lines file-name)))

(defparameter *double-word-map* (create-map "score-maps/double-word-map.txt"))
(defparameter *triple-word-map* (create-map "score-maps/triple-word-map.txt"))
(defparameter *double-letter-map* (create-map "score-maps/double-letter-map.txt"))
(defparameter *triple-letter-map* (create-map "score-maps/triple-letter-map.txt"))

(defparameter *letter-values*
  (let
    ((ht (make-hash-table))
     (ls '((1 "aeioulnstr") (2 "dg") (3 "bcmp") (4 "fhvwy") (5 "k") (8 "jx") (10 "qz"))))
    (loop for pair in ls
          for score = (car pair) do
          (loop for c in (string-to-list (cadr pair)) do
                (setf (gethash c ht) score)))
    ht))

(defun is-map-member (coord map)
  (if (member coord map :test 'equal) t))

(defun letter-scores (word)
  (loop for c in (string-to-list word) collect
        (gethash c *letter-values*)))

(defun coord-scores (coords)
  (loop for c in coords collect
       (if (is-map-member c *double-letter-map*) 2
         (if (is-map-member c *triple-letter-map*) 3 1))))

(defun word-score (word pattern coords)
  (let*
    ((ls (letter-scores word))
     (cs (coord-scores coords))
     (score (loop for i in ls
                  for j in cs
                  sum (* i j))))
    (loop for c in coords do
          (if (and (is-map-member c *double-word-map*)
                   (not (member c pattern :test 'equal)))
            (setq score (* 2 score))
            (if (and
                  (is-map-member c *triple-word-map*)
                  (not (member c pattern :test 'equal)))
              (setq score (* 3 score)))))
    score))


; VALIDATION FUNCTIONS
(defparameter *dictionary* (mapcar (lambda (s) (string-to-list (string-downcase s))) (uiop:read-file-lines "collins-scrabble-words-2019.txt")))

(defun in-dictionary (word) ; TODO 1-use function; insert into `valid-words-from-pattern'
  (numberp (position word *dictionary* :test 'equal)))

#||
(defun generate-word-permutations (word)
  (let ((snakes:*snakes-multi-mode*))
    (loop for x from 0 below (length word) append
          (snakes:generator->list (snakes:permutations
||#

(defun valid-words-from-pattern (char-list pattern blank-char)
  (let*
    ((pool (reduce 'cons char-list :initial-value (remove blank-char pattern) :from-end t))
     (snakes:*snakes-multi-mode* :list)
     (all-words (snakes:generator->list (snakes:permutations pool (length pattern)))))
    (loop for word in all-words collect
          (if (in-dictionary word) word))))

(defun highest-scoring-word-from-pattern (char-list coords pattern blank-char)
  "find the highest scoring word from a pattern"
  ; return format: (score word coords)
  (let ((top-score '(0 nil nil)))
    (loop for word in (valid-words-from-pattern char-list pattern blank-char)
          for score = (word-score word pattern coords) do
          (if (> score (car top-score))
            (setq top-score (list score word coords))))
    top-score))


; SOLVING FUNCTIONS
(defun find-play-areas (letters)
  (let ((letters-len (length letters)))
    (loop for l from 2 below (1+ letters-len) do
          (format t "@ ~a ----~&" l)
          (loop for i from 0 below (1+ (- letters-len l)) do
                (let ((start i) (end (1- (+ i l))))
                  (format t "(~a, ~a) ~a~&" start end (subseq letters start (1+ end))))))))

(defun fpl-seq-valid (seq seq-direc num char-list blank-char)
  "find all playable cells in seq from 2 to (length char-list)"
  ; return format: (start-coord end-coord pattern)
  (let* (
         (seq-len (length seq))
         (cells
          (loop for l from 2 below (1+ seq-len) append
                (loop for i from 0 to (- seq-len l) collect
                      (if (eq seq-direc 'row)
                        (list (list num i) (list num (+ i l)) (subseq seq i (+ i l)))
                        (list (list i num) (list (+ i l) num) (subseq seq i (+ i l))))))))
    ; filter out invalid cells
    (loop for c in cells
          for cbc = (count blank-char (caddr c)) do
          (if (or
               (> cbc (length char-list))
               (= cbc (length (caddr c)))
               (= 0 (count blank-char (caddr c))))
              (setq cells (remove c cells :test 'equal))))
  cells))

(defun find-play (board char-list blank-char)
  (format t "Caclulating play...~&")
  (let* ((all-cells
          (loop for row in board
                for col in (by-cols board)
                for rc from 0
                  append (fpl-seq-valid row 'row rc char-list blank-char)
                  append (fpl-seq-valid col 'col rc char-list blank-char)))
         (hi-cells-scores
           (loop for cell in all-cells collect
                 (if cell
                   (highest-scoring-word-from-pattern
                     char-list
                     (coord-range (car cell) (cadr cell))
                     (caddr cell)
                     blank-char)))))
    (car (sort hi-cells-scores '> :key 'car))))

(defun find-play-debug (board char-list blank-char)
  (format t "Caclulating play...~&")
  (let* ((all-cells
          (loop for row in board
                for col in (by-cols board)
                for rc from 0
                  append (fpl-seq-valid row 'row rc char-list blank-char)
                  append (fpl-seq-valid col 'col rc char-list blank-char))))
       (loop for cell in all-cells do
             (when cell
               (format t "cell: ~a~&" cell)
               (format t "best word: ~a~&"
                   (highest-scoring-word-from-pattern
                     char-list
                     (coord-range (car cell) (cadr cell))
                     (caddr cell)
                     blank-char))
               ))))


(defparameter *blank-char* #\-)
(defparameter *board* (create-board 15 *blank-char*))
(defparameter *letters* "")
(defparameter *idx* '((2 2) (3 2) (4 2)))

; (set-2d-list-elements *board* *letters* *idx*)

; (defparameter *play* (find-play *board* (string-to-list "cat") *blank-char*))

; (fpl-seq-valid '(#\- #\- #\r #\-) 'row 0 '(#\a #\b) #\-)
