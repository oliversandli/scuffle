(asdf:defsystem #:scuffle
  :serial t
  :description "A scrabble solver in Common Lisp."
  :author "Oliver C. Sandli <oliversandli@icloud.com>"
  :license "GNU GPLv3"
  :depends-on (#:snakes)
  :components ((:file "conversion")
               (:file "two-d")
               (:file "scoring")
               (:file "scuffle" :depends-on ("conversion" "two-d" "scoring"))))
