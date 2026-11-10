#lang eopl
;Autores: Adriana Milena Noscue Dagua 2477336, Sebastian Cucalon Astorquiza 2477344
;Santiago Torres Rojas 2380301, Nicolle Camila Hoyos Puin 2380608

#|
  Taller 3 — Cauca con referencias y tipos.
  TAD ambiente y valor procedimiento.

  Las dos definiciones van en el mismo módulo porque se nombran entre
  sí: el campo del ambiente dentro de una clausura pide ambiente?, y
  apply-env construye una clausura cuando resuelve un nombre ligado por
  letrec. Separarlas deja uno de los dos campos sin predicado.
|#

(require "sintaxis.rkt")

;; ambiente: ligaduras de identificadores a valores (el almacén va aparte).
(define-datatype ambiente ambiente?
  (ambiente-vacio)
  (ambiente-extendido
   (ids (list-of symbol?))
   (vals list?)
   (env ambiente?))
  (ambiente-recursivo
   (nombres (list-of symbol?))
   (idss (list-of (list-of symbol?)))
   (cuerpos (list-of expresion?))
   (env ambiente?)))

;; procval: valor procedimiento. Guarda parámetros, cuerpo sin evaluar y
;; el ambiente donde se creó.
(define-datatype procval procval?
  (closure
   (ids (list-of symbol?))
   (body expresion?)
   (env ambiente?)))

;; extend-env : (listof symbol) x (listof valor) x ambiente -> ambiente
;; Extiende el ambiente con ids ligados a vals; error si las longitudes difieren.
(define extend-env
  (lambda (ids vals env)
    (if (= (length ids) (length vals))
        (ambiente-extendido ids vals env)
        (eopl:error 'extend-env "Hay ~s identificadores y ~s valores"
                    (length ids) (length vals)))))

;; extend-env-recursively : (listof symbol) x (listof (listof symbol)) x
;;                          (listof expresion) x ambiente -> ambiente
;; Ambiente para letrec: guarda nombres, parámetros y cuerpos sin evaluar.
(define extend-env-recursively
  (lambda (nombres idss cuerpos env)
    (ambiente-recursivo nombres idss cuerpos env)))

;; posicion : symbol x (listof symbol) -> entero | #f
;; Índice de id en la lista, o #f si no está.
(define posicion-en-ids
  (lambda (id ids)
    (letrec ((buscar (lambda (l i)
                       (cond ((null? l) #f)
                             ((eqv? (car l) id) i)
                             (else (buscar (cdr l) (+ i 1)))))))
      (buscar ids 0))))

;; apply-env : ambiente x symbol -> valor
;; Busca la ligadura del identificador. Sobre el ambiente vacío levanta
;; eopl:error; sobre el recursivo construye la clausura del procedimiento.
(define apply-env
  (lambda (env id)
    (cases ambiente env
      (ambiente-vacio ()
        (eopl:error 'apply-env "Variable no ligada: ~s" id))
      (ambiente-extendido (ids vals ext-env)
        (let ((pos (posicion-en-ids id ids)))
          (if pos (list-ref vals pos) (apply-env ext-env id))))
      (ambiente-recursivo (nombres idss cuerpos ext-env)
        (let ((pos (posicion-en-ids id nombres)))
          (if pos
              (closure (list-ref idss pos) (list-ref cuerpos pos) env)
              (apply-env ext-env id)))))))

;; ambiente-inicial : -> ambiente
;; El del enunciado: n = 10, m = 3, p = 7, q = 2, r = 5.
(define ambiente-inicial
  (lambda ()
    (ambiente-extendido '(n m p q r) '(10 3 7 2 5) (ambiente-vacio))))

;; init-env : ambiente
;; El ambiente inicial como valor (lo usa evaluar-programa).
(define init-env (ambiente-inicial))

(provide (all-defined-out))
