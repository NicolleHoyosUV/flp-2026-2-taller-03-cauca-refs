#lang eopl
;Autores: Adriana Milena Noscue Dagua 2477336, Sebastian Cucalon Astorquiza 2477344
;Santiago Torres Rojas 2380301, Nicolle Camila Hoyos Puin 2380608

#|
  Taller 3 — Cauca con referencias y tipos.
  Evaluación y punto de entrada.

  evaluar-expresion recorre el árbol con cases y apply-procedure liga
  los parámetros de una clausura antes de evaluar su cuerpo. Las dos se
  llaman mutuamente, así que comparten módulo, y con ellas la copia por
  valor de los argumentos, que describe cómo entra un valor a apply y no
  cómo está hecha la clausura.

  El evaluador ignora las anotaciones de tipo: las lee el parser, quedan
  en el árbol y solo las usa el chequeador.

  Las cláusulas de newref-exp, deref-exp, setref-exp, swap-exp y
  begin-exp van en evaluar-expresion, junto a las demás variantes.
  Las tres que verifican con referencia? antes de tocar el almacén son
  deref-exp, setref-exp y swap-exp; si el valor no es una referencia,
  levantan eopl:error.
|#

(require "sintaxis.rkt")
(require "almacen.rkt")
(require "ambiente.rkt")
(require "primitivas.rkt")

;; copia-por-valor : valor -> valor
;; El paso por valor entrega una copia del argumento. Para un número, un
;; booleano o un procedimiento la copia es el mismo valor; para una
;; referencia es una celda nueva con el mismo contenido. applyref no usa
;; esta función: ahí el parámetro queda ligado a la misma celda.
(define copia-por-valor
  (lambda (val)
    (if (referencia? val)
        (newref! (deref val))
        val)))

;; evaluar-expresiones : list-of-expresion x ambiente -> list-of-valor
;; Propósito: Evalúa una lista de expresiones secuencialmente en el mismo ambiente.
(define evaluar-expresiones
  (lambda (exps env)
    (map (lambda (e) (evaluar-expresion e env)) exps)))

;; apply-procedure : procval x lista de valores -> valor
;; Verifica la aridad y evalúa el cuerpo en el ambiente de la clausura
;; extendido con los parámetros.
(define apply-procedure
  (lambda (proc args)
    (cases procval proc
      (closure (ids body env-saved)
        (if (= (length ids) (length args))
            (evaluar-expresion body (extend-env ids args env-saved))
            (eopl:error 'apply-procedure
                        "El procedimiento espera ~a argumentos y recibio ~a"
                        (length ids) (length args)))))))

;; evaluar-expresion : expresion x ambiente -> valor
;; Una cláusula por variante de la gramática. La condición de un if se
;; verifica con boolean? antes de ramificar.
(define evaluar-expresion
  (lambda (exp env)
    (cases expresion exp
      ;; Literales y Identificadores
      (lit-exp (datum) datum)
      (true-exp () #t)
      (false-exp () #f)
      (var-exp (id) (apply-env env id))

      ;; Primitivas
      (prim-exp (prim exps)
        (let ([args (evaluar-expresiones exps env)])
          (evaluar-primitiva prim args)))

      ;; Control de flujo
      (if-exp (test-exp then-exp else-exp)
        (let ([test-val (evaluar-expresion test-exp env)])
          (if (boolean? test-val)
              (if test-val
                  (evaluar-expresion then-exp env)
                  (evaluar-expresion else-exp env))
              (eopl:error 'evaluar-expresion 
                          "La condicion del if debe ser un booleano, se encontro: ~a" test-val))))

      (let-exp (ids exps body)
        (let ([vals (evaluar-expresiones exps env)])
          (evaluar-expresion body (extend-env ids vals env))))

      (case-exp (car-exp val-nums body-exps else-exp)
        (let ([val (evaluar-expresion car-exp env)])
          (let loop ([nums val-nums] [exps body-exps])
            (cond
              [(null? nums) (evaluar-expresion else-exp env)]
              [(= val (car nums)) (evaluar-expresion (car exps) env)]
              [else (loop (cdr nums) (cdr exps))]))))

      ;; Procedimientos
      (proc-exp (ids tipos body)
        (closure ids body env))

      (app-exp (rator rands)
        (let ([proc (evaluar-expresion rator env)]
              [args (evaluar-expresiones rands env)])
          (if (procval? proc)
              (let ([args-copiados (map copia-por-valor args)])
                (apply-procedure proc args-copiados))
              (eopl:error 'evaluar-expresion 
                          "Se intento aplicar algo que no es procedimiento: ~a" proc))))

      (app-ref-exp (rator ids)
        (let ([proc (evaluar-expresion rator env)])
          (if (procval? proc)
              (let ([refs (map (lambda (id)
                                 (let ([v (apply-env env id)])
                                   (if (referencia? v)
                                       v
                                       (eopl:error 'evaluar-expresion
                                                   "El paso por referencia exige variables ligadas a referencias: ~a" id))))
                               ids)])
                (apply-procedure proc refs))
              (eopl:error 'evaluar-expresion 
                          "Se intento aplicar algo que no es procedimiento: ~a" proc))))

      (letrec-exp (tipos-res proc-names idss tipos-args bodies body)
        (evaluar-expresion body (extend-env-recursively proc-names idss bodies env)))

      ;; ==================== Operaciones del Almacén ====================

      (newref-exp (exp)
        (let ([val (evaluar-expresion exp env)])
          (newref! val)))

      (deref-exp (exp)
        (let ([val (evaluar-expresion exp env)])
          (if (referencia? val)
              (deref val)
              (eopl:error 'evaluar-expresion 
                          "deref esperaba una referencia, se encontro: ~a" val))))

      (setref-exp (ref-exp val-exp)
        (let ([ref (evaluar-expresion ref-exp env)]
              [val (evaluar-expresion val-exp env)])
          (if (referencia? ref)
              (setref! ref val)
              (eopl:error 'evaluar-expresion 
                          "setref esperaba una referencia, se encontro: ~a" ref))))

      (swap-exp (ref1-exp ref2-exp)
        (let ([ref1 (evaluar-expresion ref1-exp env)]
              [ref2 (evaluar-expresion ref2-exp env)])
          (if (and (referencia? ref1) (referencia? ref2))
              (let ([val1 (deref ref1)]
                    [val2 (deref ref2)])
                (begin
                  (setref! ref1 val2)
                  (setref! ref2 val1)
                  val2))
              (eopl:error 'evaluar-expresion 
                          "swap requiere dos referencias"))))

      (begin-exp (exp exps)
        (let loop ([actual exp]
                   [resto exps])
          (let ([val (evaluar-expresion actual env)])
            (if (null? resto)
                val
                (loop (car resto) (cdr resto)))))))))


;; evaluar-programa : programa -> valor
;; Deja el almacén vacío y evalúa el cuerpo en el ambiente inicial.
(define evaluar-programa
  (lambda (pgm)
    (initialize-store!)
    (cases programa pgm
      (a-program (exp)
        (evaluar-expresion exp init-env)))))

;; interpretar : string -> valor
;; Analiza el texto con el parser y lo evalúa.
(define interpretar
  (lambda (texto)
    (evaluar-programa (parser texto))))

;; interpretador : -> void
;; El ciclo de lectura, con sllgen:make-rep-loop sobre evaluar-programa.
(define interpretador
  (lambda ()
    (sllgen:make-rep-loop "Cauca-Refs> " 
                          evaluar-programa
                          (sllgen:make-stream-parser especificacion-lexica especificacion-gramatical))))

(provide (all-defined-out))
