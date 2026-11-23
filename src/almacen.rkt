#lang eopl
;Autores: Adriana Milena Noscue Dagua 2477336, Sebastian Cucalon Astorquiza 2477344
;Santiago Torres Rojas 2380301, Nicolle Camila Hoyos Puin 2380608

#|
  Taller 3 — Cauca con referencias y tipos.
  TAD referencia y almacén (Parte 1).

  El módulo no requiere ningún otro: el almacén guarda valores
  cualesquiera y no necesita la gramática.

  Falta el datatype de la referencia, que es un tipo abstracto y no un
  entero desnudo:

    (define-datatype referencia referencia?
      (a-ref (pos integer?)))

  Falta también la variable global con el almacén. Es el único lugar
  del curso donde se usa set!.

  Invariante que las operaciones tienen que preservar, y que se demuestra
  en la Parte 5:
    1. toda referencia entregada por newref! apunta a una celda existente
    2. el almacén solo crece por newref!
    3. setref! cambia una celda y deja las demás intactas
    4. deref sobre una referencia fuera de rango levanta eopl:error
|#

;; TAD Referencia
;; =============================================================================

; referencia: Datatype que representa una dirección abstracta de memoria.
(define-datatype referencia referencia?
  (a-ref (pos integer?)))

;; El Almacén (Memoria global)
;; =============================================================================

;;contiene la lista de celdas del almacén.
(define the-store 'uninitialized)

;; empty-store : -> almacen
;; El almacén sin celdas.
(define empty-store
  (lambda ()
    '()))

;; initialize-store! : -> void
;; Deja el almacén vacío. Se llama al empezar cada programa.
(define initialize-store!
  (lambda ()
    (set! the-store (empty-store))))

;; get-store : () -> list
;; Propósito: Retorna el estado actual del almacén
(define get-store
  (lambda ()
    the-store))

;; newref! : valor -> referencia
;; Agrega una celda con el valor y retorna la referencia que la nombra.
(define newref!
  (lambda (val)
    (let ([len (length the-store)])
      (set! the-store (append the-store (list val)))
      (a-ref len))))

;; deref : referencia -> valor
;; Lee la celda. Si la referencia está fuera de rango, levanta eopl:error.
(define deref
  (lambda (ref)
    (cases referencia ref
      (a-ref (pos)
        (if (and (>= pos 0) (< pos (length the-store)))
            (list-ref the-store pos)
            (eopl:error 'deref "Referencia fuera de rango: ~a" pos))))))

;; replace-at : list x integer x valor -> list
;; Propósito: Función auxiliar que reemplaza el elemento en el índice pos por nuevo-val.
(define replace-at
  (lambda (lst pos nuevo-val)
    (cond
      [(null? lst) '()]
      [(= pos 0) (cons nuevo-val (cdr lst))]
      [else (cons (car lst) (replace-at (cdr lst) (- pos 1) nuevo-val))])))

;; setref! : referencia x valor -> void
;; Escribe el valor en la celda y deja las demás intactas.
(define setref!
  (lambda (ref val)
    (cases referencia ref
      (a-ref (pos)
        (if (and (>= pos 0) (< pos (length the-store)))
            (begin
              (set! the-store (replace-at the-store pos val))
              1)
            (eopl:error 'setref! "Referencia fuera de rango: ~a" pos))))))

(provide (all-defined-out))
