#lang eopl
;Autores: Nombre1 Codigo1, Nombre2 Codigo2

#|
  Taller 3 — Cauca con referencias y tipos.
  Fachada del intérprete.

  El código vive en src/, un módulo por parte del intérprete, y este
  archivo los reúne y reexporta todo lo que definen:

    src/sintaxis.rkt     especificación léxica y gramatical, datatypes, parser
    src/almacen.rkt      TAD referencia y almacén
    src/ambiente.rkt     TAD ambiente y valor procedimiento
    src/primitivas.rkt   primitivas del lenguaje
    src/interprete.rkt   evaluar-expresion, apply-procedure, interpretar y el REPL

  Las dependencias van en una sola dirección, de arriba hacia abajo.

  El archivo no lleva código propio ni pruebas: las pruebas están en
  pruebas-cauca-refs.rkt y requieren esta fachada, nunca un módulo de
  src/ por separado.
|#

(require "src/sintaxis.rkt")
(require "src/almacen.rkt")
(require "src/ambiente.rkt")
(require "src/primitivas.rkt")
(require "src/interprete.rkt")

(provide (all-from-out "src/sintaxis.rkt"
                       "src/almacen.rkt"
                       "src/ambiente.rkt"
                       "src/primitivas.rkt"
                       "src/interprete.rkt"))
