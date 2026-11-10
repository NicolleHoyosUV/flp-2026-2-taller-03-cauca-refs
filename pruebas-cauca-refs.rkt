#lang eopl
;Autores: Adriana Milena Noscue Dagua 2477336, Sebastian Cucalon Astorquiza 2477344
;Santiago Torres Rojas 2380301, Nicolle Camila Hoyos Puin 2380608

#|
  Pruebas del interpretador con referencias y del chequeador de tipos.

  Se ejecuta con:  racket pruebas-cauca-refs.rkt
|#

(require rackunit)
(require rackunit/text-ui)
(require (only-in racket/base exn:fail? with-handlers exn-message))
(require "interprete-cauca-refs.rkt")
(require "checker-cauca.rkt")

(define corre (lambda (texto) (interpretar texto)))
(define tipo-de (lambda (texto) (tipo-de-texto texto)))

;; mensaje-de : string -> string
;; El mensaje que produce el chequeador, para comprobarlo textualmente.
(define mensaje-de
  (lambda (texto)
    (with-handlers ((exn:fail? (lambda (e) (exn-message e))))
      (string-append "sin error: " (tipo-de texto)))))

;; contiene? : string x string -> boolean
(define contiene?
  (lambda (texto fragmento)
    (letrec ((desde (lambda (i)
                      (cond ((> (+ i (string-length fragmento)) (string-length texto)) #f)
                            ((string=? (substring texto i (+ i (string-length fragmento)))
                                       fragmento) #t)
                            (else (desde (+ i 1)))))))
      (desde 0))))

;;; ==========================================================
;;; Interprete
;;; ==========================================================

(define almacen
  (test-suite
   "Parte 1: almacen y expresiones nuevas"
   (test-case "newref y deref"
              (check-equal? (corre "deref(newref(42))") 42)
              (check-equal? (corre "deref(newref(true))") #t))
   (test-case "setref escribe y retorna 1"
              (check-equal? (corre "setref(newref(1), 2)") 1)
              (check-equal? (corre "let c = newref(1) in begin setref(c, 9); deref(c) end end") 9))
   (test-case "el contador sobrevive entre llamadas"
              (check-equal? (corre "let contador = newref(0)
in
  begin
    setref(contador, add1(deref(contador)));
    setref(contador, add1(deref(contador)));
    setref(contador, add1(deref(contador)));
    deref(contador)
  end
end") 3))
   (test-case "swap intercambia el contenido y retorna el nuevo valor de la primera"
              (check-equal? (corre "let a = newref(7)
    b = newref(2)
in
  begin
    swap(a, b);
    +(deref(a), *(10, deref(b)))
  end
end") 72)
              (check-equal? (corre "let a = newref(7) b = newref(2) in swap(a, b) end") 2))
   (test-case "begin evalua de izquierda a derecha y retorna la ultima"
              (check-equal? (corre "begin 1; 2; 3 end") 3)
              (check-equal? (corre "let c = newref(0)
                                    in begin setref(c, 5); setref(c, 6); deref(c) end end") 6))
   (test-case "alias: dos nombres, una sola celda"
              (check-equal? (corre "let celda = newref(5)
in
  let otro = celda
  in
    begin
      setref(otro, 99);
      deref(celda)
    end
  end
end") 99))
   (test-case "el almacen arranca vacio en cada programa"
              (check-equal? (corre "deref(newref(1))") 1)
              (check-equal? (corre "deref(newref(1))") 1))

   ;; Pruebas requeridas de la Parte 1 integradas
   (test-case "1. Crear y leer referencia"
              (check-equal? (corre "let r = newref(10) in deref(r) end") 10))
   (test-case "2. Modificar celda con setref"
              (check-equal? (corre "let r = newref(5) in begin setref(r, 20); deref(r) end end") 20))
   (test-case "3. Contador mutable que sobrevive"
              (check-equal? (corre "let c = newref(0) in begin setref(c, +(deref(c), 1)); setref(c, +(deref(c), 1)); deref(c) end end") 2))
   (test-case "4. Aliasing (dos variables apuntando a la misma celda)"
              (check-equal? (corre "let celda = newref(5) in let otro = celda in begin setref(otro, 99); deref(celda) end end end") 99))
   (test-case "5. swap entre dos referencias"
              (check-equal? (corre "let a = newref(7) in let b = newref(2) in begin swap(a, b); +(deref(a), *(10, deref(b))) end end end") 72))
   (test-case "6. Error: deref sobre un valor que no es referencia"
              (check-exn exn:fail? (lambda () (corre "deref(100)"))))
   (test-case "7. Error: setref sobre un valor que no es referencia"
              (check-exn exn:fail? (lambda () (corre "setref(5, 10)"))))
   (test-case "8. Error: swap con argumentos que no son referencias"
              (check-exn exn:fail? (lambda () (corre "let r = newref(1) in swap(r, 50) end"))))
   
   (test-case "los casos de error del almacen"
              (check-exn exn:fail? (lambda () (corre "deref(5)")))
              (check-exn exn:fail? (lambda () (corre "setref(1, 2)")))
              (check-exn exn:fail? (lambda () (corre "swap(1, newref(2))"))))))

(define paso-por-referencia
  (test-suite
   "Parte 2: paso por referencia"
   (test-case "applyref deja que el procedimiento escriba en la celda del que llama"
              (check-equal? (corre "let x = newref(11)
    y = newref(4)
in
  let intercambiar = proc (u : refto(num), v : refto(num))
                       swap(u, v)
                     end
  in
    begin
      applyref intercambiar (x, y);
      -(deref(x), deref(y))
    end
  end
end") -7))
   (test-case "el mismo programa con apply no toca las celdas del que llama"
              (check-equal? (corre "let x = newref(11)
    y = newref(4)
in
  let intercambiar = proc (u : refto(num), v : refto(num))
                       swap(u, v)
                     end
  in
    begin
      apply intercambiar (x, y);
      -(deref(x), deref(y))
    end
  end
end") 7))
   (test-case "applyref sobre una sola celda"
              (check-equal? (corre "let c = newref(1)
                                    in let poner = proc (u : refto(num)) setref(u, 100) end
                                       in begin applyref poner (c); deref(c) end end end") 100))
   (test-case "applyref con dos celdas independientes"
              (check-equal? (corre "let a = newref(1)
    b = newref(2)
in let sumar = proc (u : refto(num), v : refto(num))
                 setref(u, +(deref(u), deref(v)))
               end
   in begin applyref sumar (a, b); *(deref(a), deref(b)) end
end end") 6))
   (test-case "apply si comparte el procedimiento, no la celda"
              (check-equal? (corre "let c = newref(1)
                                    in let poner = proc (u : refto(num)) setref(u, 100) end
                                       in begin apply poner (c); deref(c) end end end") 1))
   (test-case "applyref exige variables ligadas a referencias"
              (check-exn exn:fail?
                         (lambda () (corre "let z = 1
                                            in let f = proc (u : refto(num)) deref(u) end
                                               in applyref f (z) end end"))))
   (test-case "applyref exige un procedimiento como operador"
              (check-exn exn:fail?
                         (lambda () (corre "let z = newref(1) in applyref 5 (z) end"))))))

;;; ==========================================================
;;; Chequeador
;;; ==========================================================

(define bien-tipados
  (test-suite
   "Parte 3: programas bien tipados"
   (test-case "procedimiento anotado"
              (check-equal? (tipo-de "proc (a : num, b : num) +(a, b) end") "(num * num -> num)"))
   (test-case "celda con lectura y escritura"
              (check-equal? (tipo-de "let celda = newref(0)
in
  begin
    setref(celda, 42);
    deref(celda)
  end
end") "num"))
   (test-case "newref anida los tipos"
              (check-equal? (tipo-de "newref(newref(true))") "refto(refto(bool))"))
   (test-case "swap devuelve el tipo de la celda"
              (check-equal? (tipo-de "let a = newref(1) b = newref(2) in swap(a, b) end") "num"))
   (test-case "letrec recursivo"
              (check-equal? (tipo-de "letrec num fact (k : num) =
                                        if ==(k, 0) then 1 else *(k, apply fact (sub1(k))) end
                                      in apply fact (5) end") "num"))
   (test-case "applyref con una celda"
              (check-equal? (tipo-de "let x = newref(1)
                                      in let f = proc (u : refto(num)) deref(u) end
                                         in applyref f (x) end end") "num"))
   (test-case "case con ramas del mismo tipo"
              (check-equal? (tipo-de "case n of 1 => 10 2 => 20 else 0 end") "num"))
   (test-case "procedimiento de orden superior"
              (check-equal? (tipo-de "proc (f : (num -> num), x : num) apply f (x) end")
                            "((num -> num) * num -> num)"))))

(define mal-tipados
  (test-suite
   "Parte 3: cada mensaje de error"
   (test-case "la condicion del if no es booleana"
              (check-true (contiene? (mensaje-de "if n then 1 else 2 end")
                                     "La condicion del if debe ser bool, se encontro num")))
   (test-case "las ramas del if no coinciden"
              (check-true (contiene? (mensaje-de "if >(n, m) then 1 else false end")
                                     "Las ramas del if deben coincidir: num vs bool")))
   (test-case "se aplica algo que no es procedimiento"
              (check-true (contiene? (mensaje-de "apply 5 (1)")
                                     "Se intento aplicar un valor de tipo num")))
   (test-case "aridad incorrecta"
              (check-true (contiene? (mensaje-de "let f = proc (a : num, b : num) +(a, b) end
                                                  in apply f (1) end")
                                     "El procedimiento espera 2 argumentos y recibio 1")))
   (test-case "argumento de tipo equivocado"
              (check-true (contiene? (mensaje-de "let f = proc (a : num) a end
                                                  in apply f (true) end")
                                     "El argumento 1 debe ser num, se encontro bool")))
   (test-case "deref sobre algo que no es referencia"
              (check-true (contiene? (mensaje-de "deref(5)")
                                     "deref espera refto(t), se encontro num")))
   (test-case "setref con tipos incompatibles"
              (check-true (contiene? (mensaje-de "let celda = newref(0)
                                                  in setref(celda, true) end")
                                     "La celda guarda num y se intento escribir bool")))
   (test-case "el cuerpo del letrec no da el tipo declarado"
              (check-true (contiene? (mensaje-de "letrec num f (k : num) = true
                                                  in apply f (1) end")
                                     "El procedimiento f declara num y su cuerpo da bool")))
   (test-case "identificador no declarado"
              (check-true (contiene? (mensaje-de "z") "Variable no declarada: z")))
   (test-case "applyref con una variable que no es referencia"
              (check-exn exn:fail?
                         (lambda () (tipo-de "let z = 1
                                              in let f = proc (u : refto(num)) deref(u) end
                                                 in applyref f (z) end end"))))))
(define paso-por-referencia-extra
  (test-suite
   "Parte 2 (grupo): ejemplos adicionales de paso por referencia"
   (test-case "contador con applyref: la escritura se ve afuera"
              (check-equal? (corre "let c = newref(0) inc = proc (r : refto(num)) setref(r, add1(deref(r))) end in begin applyref inc (c); applyref inc (c); deref(c) end end") 2))
   (test-case "contador con apply: la escritura se pierde"
              (check-equal? (corre "let c = newref(0) inc = proc (r : refto(num)) setref(r, add1(deref(r))) end in begin apply inc (c); apply inc (c); deref(c) end end") 0))
   (test-case "sumar a en b con applyref"
              (check-equal? (corre "let a = newref(3) b = newref(4) sumar = proc (x : refto(num), y : refto(num)) setref(x, +(deref(x), deref(y))) end in begin applyref sumar (a, b); deref(a) end end") 7))
   (test-case "alias: d y c comparten la celda y applyref la respeta"
              (check-equal? (corre "let c = newref(0) inc = proc (r : refto(num)) setref(r, add1(deref(r))) end in let d = c in begin applyref inc (d); deref(c) end end end") 1))
   (test-case "error: argumento ligado a un numero, no a una referencia"
              (check-exn exn:fail?
                         (lambda () (corre "let f = proc (r : refto(num)) deref(r) end in applyref f (n) end"))))
   (test-case "error: aridad incorrecta"
              (check-exn exn:fail?
                         (lambda () (corre "let c = newref(1) f = proc (r : refto(num)) deref(r) end in applyref f (c, c) end"))))
   (test-case "error: el operador no es un procedimiento"
              (check-exn exn:fail?
                         (lambda () (corre "let c = newref(1) in applyref c (c) end"))))))



(define fallidas
  (+ (run-tests almacen)
     (run-tests paso-por-referencia)
     (run-tests paso-por-referencia-extra)
     (run-tests bien-tipados)
     (run-tests mal-tipados)))

(eopl:printf "~%==========================================~%")
(eopl:printf "  pruebas fallidas en total: ~s~%" fallidas)
(eopl:printf "==========================================~%")






