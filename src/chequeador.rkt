#lang eopl
;Autores: Adriana Milena Noscue Dagua 2477336, Sebastian Cucalon Astorquiza 2477344
;Santiago Torres Rojas 2380301, Nicolle Camila Hoyos Puin 2380608

#|
  Taller 3 — Cauca con referencias y tipos.
  Reglas de tipado y chequeo del programa (Parte 3).

  type-of recorre el árbol con cases sobre un ambiente de tipos y no
  evalúa nada: una regla por variante de expresión, tal como están
  escritas en el cuadro del enunciado.

  Los mensajes de error se distinguen uno de otro. Son los nueve del
  cuadro «Mensajes de error», con ese texto.

  El módulo requiere sintaxis.rkt y tipos.rkt, y ningún otro módulo del
  intérprete: el árbol que recorre es el que produjo el parser, con las
  anotaciones de tipo adentro.
|#

(require "sintaxis.rkt")
(require "tipos.rkt")

;; chequear-aplicacion : list-of-tipo x list-of-tipo x tipo -> tipo
;; Propósito: Verifica la aridad y los tipos de los argumentos pasados a un procedimiento.
(define chequear-aplicacion
  (lambda (formales reales retorno)
    (let ([n (length formales)]
          [k (length reales)])
      (if (not (= n k))
          (eopl:error 'type-of "El procedimiento espera ~a argumentos y recibio ~a" n k)
          (let loop ([idx 1] [f formales] [r reales])
            (cond
              [(null? f) retorno]
              [(not (tipos-iguales? (car f) (car r)))
               (eopl:error 'type-of "El argumento ~a debe ser ~a, se encontro ~a"
                           idx (tipo->texto (car f)) (tipo->texto (car r)))]
              [else (loop (+ idx 1) (cdr f) (cdr r))]))))))

;; verificar-refs : list-of-tipo -> boolean
;; Propósito: Verifica que el tipo de cada argumento de applyref sea refto(t).
(define verificar-refs
  (lambda (tipos)
    (let loop ([idx 1] [ts tipos])
      (if (null? ts)
          #t
          (cases tipo (car ts)
            (ref-tipo (t-elem) (loop (+ idx 1) (cdr ts)))
            (else
             (eopl:error 'type-of "El argumento ~a debe ser refto(t), se encontro ~a"
                         idx (tipo->texto (car ts)))))))))

;; type-of : expresion x tenv -> tipo
;; El tipo de la expresión bajo el ambiente de tipos, o eopl:error con
;; el mensaje que explique el conflicto.
(define type-of
  (lambda (exp amb)
    (cases expresion exp
      ;; Literales e Identificadores
      (lit-exp (datum) (num-tipo))
      (true-exp () (bool-tipo))
      (false-exp () (bool-tipo))
      (var-exp (id) (apply-tenv amb id))

      ;; Primitivas
      (prim-exp (prim exps)
        (let ([tipos-args (map (lambda (e) (type-of e amb)) exps)])
          (tipo-de-primitiva prim tipos-args)))

      ;; Control de flujo (if)
      (if-exp (test-exp then-exp else-exp)
        (let ([tipo-test (type-of test-exp amb)])
          (if (not (tipos-iguales? tipo-test (bool-tipo)))
              (eopl:error 'type-of "La condicion del if debe ser bool, se encontro ~a" (tipo->texto tipo-test))
              (let ([tipo-then (type-of then-exp amb)]
                    [tipo-else (type-of else-exp amb)])
                (if (not (tipos-iguales? tipo-then tipo-else))
                    (eopl:error 'type-of "Las ramas del if deben coincidir: ~a vs ~a"
                                (tipo->texto tipo-then) (tipo->texto tipo-else))
                    tipo-then)))))

      ;; Let
      (let-exp (ids exps body)
        (let ([tipos-exps (map (lambda (e) (type-of e amb)) exps)])
          (type-of body (extend-tenv ids tipos-exps amb))))

      ;; Case
      (case-exp (car-exp val-nums body-exps else-exp)
        (let ([tipo-car (type-of car-exp amb)])
          (unless (tipos-iguales? tipo-car (num-tipo))
            (eopl:error 'type-of "case evalua sobre un entero"))
          (let ([tipo-else (type-of else-exp amb)])
            (for-each (lambda (b-exp)
                        (let ([t-b (type-of b-exp amb)])
                          (unless (tipos-iguales? t-b tipo-else)
                            (eopl:error 'type-of "Las ramas de case deben tener el mismo tipo"))))
                      body-exps)
            tipo-else)))

      ;; Procedimientos (proc)
      (proc-exp (ids tipos body)
        (let ([tipo-cuerpo (type-of body (extend-tenv ids tipos amb))])
          (proc-tipo tipos tipo-cuerpo)))

      ;; Aplicación por valor (apply)
      (app-exp (rator rands)
        (let ([tipo-rator (type-of rator amb)]
              [tipos-rands (map (lambda (e) (type-of e amb)) rands)])
          (cases tipo tipo-rator
            (proc-tipo (tipos-formales tipo-retorno)
              (chequear-aplicacion tipos-formales tipos-rands tipo-retorno))
            (else
             (eopl:error 'type-of "Se intento aplicar un valor de tipo ~a"
                         (tipo->texto tipo-rator))))))

      ;; Aplicación por referencia (applyref)
      (app-ref-exp (rator ids)
        (let ([tipo-rator (type-of rator amb)]
              [tipos-ids (map (lambda (id) (apply-tenv amb id)) ids)])
          (cases tipo tipo-rator
            (proc-tipo (tipos-formales tipo-retorno)
              (verificar-refs tipos-ids)
              (chequear-aplicacion tipos-formales tipos-ids tipo-retorno))
            (else
             (eopl:error 'type-of "Se intento aplicar un valor de tipo ~a"
                         (tipo->texto tipo-rator))))))

      ;; Letrec
      (letrec-exp (tipos-res proc-names idss tipos-args bodies body)
        (let ([env-extendido (extend-tenv-recursively proc-names idss tipos-args tipos-res amb)])
          (for-each
           (lambda (id id-list arg-types res-type b-exp)
             (let ([tipo-cuerpo (type-of b-exp (extend-tenv id-list arg-types env-extendido))])
               (unless (tipos-iguales? tipo-cuerpo res-type)
                 (eopl:error 'type-of "El procedimiento ~a declara ~a y su cuerpo da ~a"
                             id (tipo->texto res-type) (tipo->texto tipo-cuerpo)))))
           proc-names idss tipos-args tipos-res bodies)
          (type-of body env-extendido)))

      ;;Operaciones del Almacen

      (newref-exp (exp)
        (let ([tipo-exp (type-of exp amb)])
          (ref-tipo tipo-exp)))

      (deref-exp (exp)
        (let ([tipo-exp (type-of exp amb)])
          (cases tipo tipo-exp
            (ref-tipo (t-elem) t-elem)
            (else
             (eopl:error 'type-of "deref espera refto(t), se encontro ~a"
                         (tipo->texto tipo-exp))))))

      (setref-exp (ref-exp val-exp)
        (let ([tipo-ref (type-of ref-exp amb)]
              [tipo-val (type-of val-exp amb)])
          (cases tipo tipo-ref
            (ref-tipo (t-elem)
              (if (not (tipos-iguales? t-elem tipo-val))
                  (eopl:error 'type-of "La celda guarda ~a y se intento escribir ~a"
                              (tipo->texto t-elem) (tipo->texto tipo-val))
                  (num-tipo)))
            (else
             (eopl:error 'type-of "setref espera refto(t), se encontro ~a"
                         (tipo->texto tipo-ref))))))

      (swap-exp (ref1-exp ref2-exp)
        (let ([tipo1 (type-of ref1-exp amb)]
              [tipo2 (type-of ref2-exp amb)])
          (cases tipo tipo1
            (ref-tipo (t1)
              (cases tipo tipo2
                (ref-tipo (t2)
                  (if (not (tipos-iguales? t1 t2))
                      (eopl:error 'type-of "swap requiere referencias al mismo tipo: ~a vs ~a"
                                  (tipo->texto t1) (tipo->texto t2))
                      t1))
                (else
                 (eopl:error 'type-of "swap espera refto(t), se encontro ~a" (tipo->texto tipo2)))))
            (else
             (eopl:error 'type-of "swap espera refto(t), se encontro ~a" (tipo->texto tipo1))))))

      (begin-exp (exp exps)
        (let loop ([actual exp] [resto exps])
          (let ([tipo-actual (type-of actual amb)])
            (if (null? resto)
                tipo-actual
                (loop (car resto) (cdr resto)))))))))


;; type-of-program : programa -> tipo
;; Chequea el programa en el ambiente de tipos inicial.
(define type-of-program
  (lambda (pgm)
    (cases programa pgm
      (a-program (exp)
                 (tipo->texto (type-of exp (tenv-inicial)))))))


;; tipo-de-texto : string -> string
;; Analiza el texto, lo chequea y describe el tipo resultante.
(define tipo-de-texto
  (lambda (texto)
    (type-of-program (parser texto))))

;; chequeador : -> void
;; Propósito: REPL interactivo para probar el chequeador de tipos en la consola.
(define chequeador
  (lambda ()
    (sllgen:make-rep-loop "Cauca-Checker> " 
                          type-of-program
                          (sllgen:make-stream-parser especificacion-lexica especificacion-gramatical))))

(provide (all-defined-out))
