#lang eopl
;Autores: Adriana Milena Noscue Dagua 2477336, Sebastian Cucalon Astorquiza 2477344
;Santiago Torres Rojas 2380301, Nicolle Camila Hoyos Puin 2380608

(require "sintaxis.rkt")

;; verificar-cantidad : symbol x lista x entero -> #t
;; Propósito: error si la lista no tiene exactamente n elementos.
(define verificar-cantidad
  (lambda (nombre args n)
    (if (= (length args) n)
        #t
        (eopl:error nombre "Se esperaban ~s argumentos y se recibieron ~s" n (length args)))))

;; verificar-minimo : symbol x lista x entero -> #t
;; Propósito: error si la lista tiene menos de n elementos.
(define verificar-minimo
  (lambda (nombre args n)
    (if (>= (length args) n)
        #t
        (eopl:error nombre "Se esperaban al menos ~s argumentos y se recibieron ~s" n (length args)))))

;; verificar-numeros : symbol x lista -> #t
;; Propósito: error si algún argumento no es número.
(define verificar-numeros
  (lambda (nombre args)
    (if (null? args)
        #t
        (if (number? (car args))
            (verificar-numeros nombre (cdr args))
            (eopl:error nombre "Se esperaba un numero y se recibio ~s" (car args))))))

;; verificar-enteros : symbol x lista -> #t
;; Propósito: error si algún argumento no es un entero.
(define verificar-enteros
  (lambda (nombre args)
    (if (null? args)
        #t
        (if (and (number? (car args)) (integer? (car args)))
            (verificar-enteros nombre (cdr args))
            (eopl:error nombre "Se esperaba un entero y se recibio ~s" (car args))))))

;; verificar-booleanos : symbol x lista -> #t
;; Propósito: error si algún argumento no es booleano.
(define verificar-booleanos
  (lambda (nombre args)
    (if (null? args)
        #t
        (if (boolean? (car args))
            (verificar-booleanos nombre (cdr args))
            (eopl:error nombre "Se esperaba un booleano y se recibio ~s" (car args))))))

;; reducir-izq : (valor x valor -> valor) x lista no vacía -> valor
;; Propósito: pliega la lista de izquierda a derecha con f.
(define reducir-izq
  (lambda (f args)
    (if (null? (cdr args))
        (car args)
        (reducir-izq f (cons (f (car args) (cadr args)) (cddr args))))))

;; aritmetica-n : symbol x (num x num -> num) x lista -> numero
;; Propósito: primitiva aritmética n-aria (n >= 2) con verificación de tipo.
(define aritmetica-n
  (lambda (nombre f args)
    (begin
      (verificar-minimo nombre args 2)
      (verificar-numeros nombre args)
      (reducir-izq f args))))

;; enteros-n : symbol x (int x int -> int) x lista -> entero
;; Propósito: primitiva n-aria (n >= 2) sobre enteros (mcd, mcm).
(define enteros-n
  (lambda (nombre f args)
    (begin
      (verificar-minimo nombre args 2)
      (verificar-enteros nombre args)
      (reducir-izq f args))))

;; relacional : symbol x (num x num -> bool) x lista -> booleano
;; Propósito: primitiva relacional binaria con verificación de tipo.
(define relacional
  (lambda (nombre f args)
    (begin
      (verificar-cantidad nombre args 2)
      (verificar-numeros nombre args)
      (f (car args) (cadr args)))))

;; booleana-2 : symbol x (bool x bool -> bool) x lista -> booleano
;; Propósito: primitiva booleana binaria con verificación de tipo.
(define booleana-2
  (lambda (nombre f args)
    (begin
      (verificar-cantidad nombre args 2)
      (verificar-booleanos nombre args)
      (f (car args) (cadr args)))))

;; unaria-num : symbol x (num -> num) x lista -> numero
;; Propósito: primitiva unaria sobre números.
(define unaria-num
  (lambda (nombre f args)
    (begin
      (verificar-cantidad nombre args 1)
      (verificar-numeros nombre args)
      (f (car args)))))

;; dividir : num x num -> num
;; Propósito: división; error si el divisor es cero.
(define dividir
  (lambda (a b)
    (if (zero? b)
        (eopl:error '/ "Division por cero")
        (/ a b))))

;; suma-lista : lista de números -> número
;; Propósito: suma los elementos de la lista.
(define suma-lista
  (lambda (l)
    (if (null? l) 0 (+ (car l) (suma-lista (cdr l))))))

;; evaluar-primitiva : primitiva x (listof valor) -> valor
;; Propósito: aplica la primitiva a los argumentos ya evaluados, verificando
;; cantidad y tipo de los argumentos.
(define evaluar-primitiva
  (lambda (prim args)
    (cases primitiva prim
      (sum-prim () (aritmetica-n '+ + args))
      (sub-prim () (aritmetica-n '- - args))
      (mult-prim () (aritmetica-n '* * args))
      (add1-prim () (unaria-num 'add1 (lambda (x) (+ x 1)) args))
      (sub1-prim () (unaria-num 'sub1 (lambda (x) (- x 1)) args))
      (greater-prim () (relacional '> > args))
      (greater-equal-prim () (relacional '>= >= args))
      (less-prim () (relacional '< < args))
      (less-equal-prim () (relacional '<= <= args))
      (equal-prim () (relacional '== = args))
      (not-prim ()
        (begin (verificar-cantidad 'not args 1) (verificar-booleanos 'not args)
               (not (car args))))
      (and-prim () (booleana-2 'and (lambda (a b) (and a b)) args))
      (or-prim () (booleana-2 'or (lambda (a b) (or a b)) args))
      ;; Primitivas que la gramática actual no tiene. Si se agregan a
      ;; sintaxis.rkt, se descomenta la cláusula con el mismo nombre de constructor:
      ;; (div-prim () (aritmetica-n '/ dividir args))
      ;; (abs-prim () (unaria-num 'abs abs args))
      ;; (mcd-prim () (enteros-n 'mcd gcd args))
      ;; (mcm-prim () (enteros-n 'mcm lcm args))
      ;; (promedio-prim ()
      ;;   (begin (verificar-minimo 'promedio args 1) (verificar-numeros 'promedio args)
      ;;          (/ (suma-lista args) (length args))))
      ;; (xor-prim () (booleana-2 'xor (lambda (a b) (not (eq? a b))) args))
      ;; (implica-prim () (booleana-2 'implica (lambda (a b) (or (not a) b)) args))
      ;; (entre-prim ()
      ;;   (begin (verificar-cantidad 'entre args 3) (verificar-numeros 'entre args)
      ;;          (and (<= (cadr args) (car args)) (<= (car args) (caddr args)))))
      )))

(provide (all-defined-out))