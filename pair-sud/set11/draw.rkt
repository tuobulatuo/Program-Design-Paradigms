#lang racket
(require "extras.rkt")
(require rackunit)
(require lang/posn)
(require 2htdp/image)
(require 2htdp/universe)
(define TIME-ON-TASK 18)

(provide INITIAL-WORLD)
(provide handle-mouse)
(provide Shape<%>)
(provide get-world-shapes)
(provide create-rectangle)
(provide create-circle)

; constants
(define MT (empty-scene 600 400))
(define BLACK-SQUARE (rectangle 20 20 "solid" "black"))
(define WHITE-SQUARE (rectangle 20 20 "outline" "black"))
(define WHITE-P (text "p" 16 "white"))
(define BLACK-P (text "p" 16 "black"))
(define WHITE-R (text "r" 16 "white"))
(define BLACK-R (text "r" 16 "black"))
(define WHITE-C (text "c" 16 "white"))
(define BLACK-C (text "c" 16 "black"))
(define POSN (make-posn 0 0))
(define VS (make-posn 0 0))
(define TOOLBAR-LEFT 0)
(define TOOLBAR-RIGHT 20)
(define TOOLBAR-TOP 0)
(define TOOLBAR-BOTTOM 60)
(define BETWEEN/P/R 20)
(define BETWEEN/R/C 40)

; A BoundingBox is a (list Coordinate Coordinate Coordinate Coordinate)
; INTERPRETATION: (list left top right bottom).
; A BoundingBox represents a box whose left x-coordinate is at "left", whose
; top y-coordinate is at "top", whose right x-coordinate is at "right", and 
; whose bottom y-coordinate is at "bottom".
; Template:
; boundingBox-fn : BoundingBox -> ???
; Strategy: data decomposition on bb: BoundingBox
;(define (boundingBox-fn bb)
;  (...(first bb)...(second bb)...(third bb)...(fourth bb)))

; A ShapeState is one of:
; - created
; - creating
; - moving
; - resizing
; Represents the current state of the shape
(define created "created")
(define creating "creating")
(define moving "moving")
(define resizing "resizing")
; Template: 
; shapeState-fn: ShapeState -> ???
; Strategy: data decomposition on ss: ShapeState
;(define (shapeState-fn ss)
;  (cond
;    [(created? ss) ...]
;    [(creating? ss) ...]
;    [(moving? ss) ...]
;    [(resizing? ss) ...]))

; created?: ShapeState -> Boolean
; creating?: ShapeState -> Boolean
; moving?: ShapeState -> Boolean
; resizing?: ShapeState -> Boolean
; Returns true if the current state is created/creating/moving/resizing.
; Strategy: Function composition
(begin-for-test
  (check-true (created? created))
  (check-true (creating? creating))
  (check-true (moving? moving))
  (check-true (resizing? resizing)))
(define (created? state)
  (string=? state created))
(define (creating? state)
  (string=? state creating))
(define (moving? state)
  (string=? state moving))
(define (resizing? state)
  (string=? state resizing))

; A DrawState is one of:
; - pointer
; - rectangle
; - circle
(define pointer "pointer")
(define rec "rectangle")
(define cir "circle")
; Template:
; drawState-fn -> ???
; Strategy: data decomposition on ds: DrawState
;(define (drawState-fn ds)
;  (cond
;    [(pointer? ds) ...]
;    [(rectangle? ds) ...]
;    [(circle? ds) ...]))

; pointer? : String -> Boolean
; Returns true if string matches
; Strategy: Function composition
(begin-for-test
  (check-equal? (pointer? "pointer") #true
                "Test failed. Function should return true"))
(define (pointer? state)
  (string=? pointer state))

; rectangle? : String -> Boolean
; Returns true if string matches
; Strategy: Function composition
(begin-for-test
  (check-equal? (rectangle? "rectangle") #true
                "Test failed. Function should return true"))
(define (rectangle? state)
  (string=? rec state))

; circle? : String -> Boolean
; Returns true if string matches
; Strategy: Function composition
(begin-for-test
  (check-equal? (circle? "circle") #true
                "Test failed. Function should return true"))
(define (circle? state)
  (string=? cir state))

(define TestCircle<%>
  (interface ()
    ; testing:get-state: -> ShapeState
    ; Returns the ShapeState of the circle
    testing:get-state
    
    ; testing:get-vs: -> Posn
    ; Returns the vector's start point of the circle
    testing:get-vs
    
    ; testing:get-center: -> Posn
    ; Returns the center's position of the circle
    testing:get-center
    
    ; testing:get-radius: -> Integer
    ; Returns the radius of the circle
    testing:get-radius))

(define TestRectangle<%>
  (interface ()
    ; testing:get-stable : -> Posn
    ; Returns the stable point of the rectangle
    testing:get-stable
    
    ; testing:get-dynamic : -> Posn
    ; Returns the dynamic point of the rectangle
    testing:get-dynamic
    
    ; testing:get-state : -> ShapeState
    ; Returns the ShapeState of the rectangle
    testing:get-state
    
    ; testing:get-vs: -> Posn
    ; Returns the vector's start point of the circle
    testing:get-vs))

(define Shape<%>
  (interface ()
    ; get-bounds : -> BoundingBox
    ; Returns the BoundingBox of this shape
    get-bounds
    
    ; handle-mouse : Coordinate Coordinate MouseEvent -> Shape<%>
    ; Returns a new shape after handling MouseEvent on this shape
    handle-mouse))

(define Drawable<%>
  (interface ()
    ; draw -> Image
    ; Return a Image which is the image of the shape
    draw
    
    ; get-centerX -> Posn
    ; Returns a Posn, which represents the x-coordinate of the shape' center.
    get-centerX
    
    ; get-centerY -> Posn
    ; Returns a Posn, which represents the y-coordinate of the shape' center.
    get-centerY))

; Rectangle% : A class that satisfies the Drawable<%> interface
; A Rectangle is a (new Rectangle [stable Posn] [dynamic Posn] 
;                                         [state ShapeState] [v/s Posn])
; INTERP : Represents a rectangle, with a stable and dynamic point, state
; and vector start point
(define Rectangle%
  (class* object% (Shape<%> Drawable<%> TestRectangle<%>)
    
    (init-field stable dynamic state v/s)
    ; INTERPRETATION: 'stable' is the posn for stable point of the shape,
    ; 'dynamic' is the posn for the dynamic point of the shape which changes 
    ; during the drag event, 
    ; 'state' is a ShapeState that represents the current state of the shape
    ; 'v/s' is a posn for vector for moving the shape
    
    ; set-stable : Posn -> Rectangle%
    ; Returns a new rectangle by assigning a new position
    (define/public (set-stable p)
      (set-field! stable this p))
    
    ; set-stable : Posn -> Rectangle%
    ; Returns a new rectangle by assigning a new position
    (define/public (set-dynamic p)
      (set-field! dynamic this p))
    
    ; limitation of control boundary
    (define CONTROL-BOUNDARY 5) 
    ; STABLE and DYNAMIC are only used during moving, representing the initial
    ; two start point of the shape, which will be added to the drag vector to 
    ; calculate the current position of the shape.
    (define STABLE stable)      
    (define DYNAMIC dynamic)
    
    ; get-bounds : -> ListOfCoordinate
    ; Returns a list of coordinate representing a rectangle
    ; Startegy: Data decomposition on stable,dynamic : Posn
    (define/public (get-bounds) (list (min (posn-x stable) (posn-x dynamic))
                                      (min (posn-y stable) (posn-y dynamic))
                                      (max (posn-x stable) (posn-x dynamic))
                                      (max (posn-y stable) (posn-y dynamic))))
    
    ; handle-mouse : Coordinate Coordinate MouseEvent -> Rectangle%
    ; Returns the object of the class depending upon the mouse event
    ; Startegy: Data decomposition on e : MouseEvent
    (define/public (handle-mouse cx cy e) 
      (cond 
        [(string=? e "button-down") (gesture-start cx cy)]
        [(string=? e "drag") (gesturing cx cy)]
        [(string=? e "button-up") (gesture-end cx cy)]
        [else this]))
    
    ; gesture-start : Coordinate Coordinate -> MaybeRectangle%
    ; Returns a new rectangle or an error by checking the state of the object
    ; Strategy: Data decomposition on state: ShapeState
    (define (gesture-start cx cy)
      (cond
        [(or (moving? state) (resizing? state) (creating? state) ) 
         (build/r (make-posn cx cy) (make-posn cx cy) state VS)]
        [(created? state) (init/resize/move cx cy)]))
    
    ; init/resize/move : Coordinate Coordinate -> Rectangle%
    ; Init resize sate or move state a rectangle depending on the current state 
    ; of object
    (define (init/resize/move cx cy)
      (local((define stable (control-posn cx cy)))
        (if (posn? stable)
            (init-resize stable cx cy)
            (if (inside/this? cx cy)
                (init-move cx cy)
                this))))
    
    ; init-resize : Posn Coordinate Coordinate -> Rectangle% 
    ; Returns a new initialized resize state rectangle by changing the dynamic 
    ; point of rectangle
    (define (init-resize stable cx cy)
      (build/r stable (make-posn cx cy) resizing VS))
    
    ; init-move : Posn Coordinate Coordinate -> Rectangle% 
    ; Returns a new initialized move state rectangle by changing the vector 
    ; position
    (define (init-move cx cy)
      (build/r stable dynamic moving (make-posn cx cy)))
    
    ; gesturing : Coordinate Coordinate -> Rectangle%
    ; Returns a new rectangle based on the state of the rectangle when draging
    ; the mouse
    ; Strategy: Data decomposition on state: ShapeState
    (define (gesturing cx cy)
      (cond
        [(or (resizing? state) (creating? state))
         (build/r stable (make-posn cx cy) state VS)]
        [(moving? state) (add/vector cx cy)]
        [(created? state) this]))
    
    ; add/vector : Coordinate Coordinate -> Rectangle%
    ; Returns the current rectangle with stable and dynamic positions updated
    ; according to the coordinates passed and initial posn.
    ; Startegy: Data decomposition on stable, dynamic : Posn
    (define (add/vector cx cy)
      (local((define vx (- cx (posn-x v/s)))
             (define vy (- cy (posn-y v/s)))
             (define v (send* this 
                         (set-stable (make-posn (+ (posn-x STABLE) vx)
                                                (+ (posn-y STABLE) vy)))
                         (set-dynamic (make-posn (+ (posn-x DYNAMIC) vx) 
                                                 (+ (posn-y DYNAMIC) vy))))))
        this))
    
    ; gesture-end : Coordinate Coordinate -> Rectangle%
    ; Returns a new rectangle with state as created
    (define (gesture-end cx cy)
      (build/r stable dynamic created VS))
    
    ; control-posn : Coordinate Coordinate -> Maybe<Posn>
    ; Returns a the stable posn by the given click point, if the click point is
    ; within the control regin of any coners of the rectanle.
    ; Example: lets assume the four coners of the rectangle are (c1 c2 c3 c4) in
    ; clockwise order. If the click point is within control region of c1, return
    ; c3, if c2, returns c4 and so on.
    (define (control-posn cx cy)
      (local((define coner1 (make-posn (posn-x stable) (posn-y dynamic)))
             (define coner2 (make-posn (posn-x dynamic) (posn-y stable)))
             (define coners (list stable dynamic coner1 coner2))
             (define hashmap (make-hash (list (list coner1 coner2) 
                                              (list coner2 coner1)
                                              (list stable dynamic)
                                              (list dynamic stable))))
             (define control-region 
               (filter (lambda (c) (inside? c cx cy 
                                            CONTROL-BOUNDARY CONTROL-BOUNDARY))
                       coners)))
        (if (empty? control-region)
            #false
            (first (hash-ref hashmap (first control-region))))))
    
    ; inside? : Posn Coordinate Coordinate Integer Integer -> Boolean
    ; Returns true if the mouse click (x, y) is inside the rectangle,
    ; which defined by (center, dis-x, dis-y) where center is the center of
    ; the rectanle, dis-x, dis-y represents the distance to the center.
    ; Strategy: Data decomposition on center : Posn
    (define (inside? center x y dis-x dis-y)
      (and (<= (abs (- x (posn-x center))) dis-x) 
           (<= (abs (- y (posn-y center))) dis-y)))
    
    ; inside/this? : Coordinate Coordinate -> Boolean
    ; Returns true if the mouse click is inside the rectangle
    ; Strategy: Data decomposition on stable,dynamic : Posn
    (define (inside/this? cx cy)
      (inside? (make-posn (get-centerX) (get-centerY))
               cx cy 
               (/ (abs (- (posn-x stable) (posn-x dynamic))) 2)
               (/ (abs (- (posn-y stable) (posn-y dynamic))) 2)))
    
    ; draw : -> Image
    ; Returns an image of the rectangle
    ; Strategy: Data decomposition on stable,dynamic : Posn
    (define/public (draw) 
      (cond
        [(string=? creating state) 
         (rectangle (abs (- (posn-x stable) (posn-x dynamic))) 
                    (abs (- (posn-y stable) (posn-y dynamic)))
                    127 "red")]
        [else (rectangle (abs (- (posn-x stable) (posn-x dynamic))) 
                         (abs (- (posn-y stable) (posn-y dynamic)))
                         "outline" "black")]))
    
    ; get-centerX : -> Coordinate
    ; Returns the x coordinate of the center of the rectangle
    ; Strategy: Data decomposition on stable,dynamic : Posn
    (define/public (get-centerX) 
      (/ (+ (posn-x stable) (posn-x dynamic)) 2))
    
    ; get-centerY : -> Coordinate
    ; Returns the y coordinate of the center of the rectangle
    ; Strategy: Data decomposition on stable,dynamic : Posn
    (define/public (get-centerY) 
      (/ (+ (posn-y stable) (posn-y dynamic)) 2))
    
    ; testing:get-stable : -> Posn
    (define/public (testing:get-stable)
      stable)
    
    ; testing:get-dynamic : -> Posn
    (define/public (testing:get-dynamic)
      dynamic)
    
    ; testing:get-state : -> ShapeState
    (define/public (testing:get-state)
      state)
    
    ; testing:get-vs: -> Posn
    (define/public (testing:get-vs)
      v/s)
    (super-new)))

; Circle% : A class that satisfies the Drawable<%> interface
; A circle is a (new Rectangle [center Posn] [radius PosInt] 
;                                    [state StateShape] [v/s Posn])
; INTERP : Represents a circle with a center, radius, state
; and vector
(define Circle%
  (class* object% (Shape<%> Drawable<%> TestCircle<%>)
    (init-field center radius state v/s)
    ; INTERPRETATION: 'center' is the posn for center of the circle,
    ; 'radius' is the positive integer for the circle which changes 
    ; during the drag event, 
    ; 'state' is a ShapeState that represents the current state of the shape
    ; 'v/s' is a posn for vector for moving the shape
    
    ; set-center : Posn -> Circle%
    ; Returns a new circle by assigning a new position to center
    (define/public (set-center c)
      (set-field! center this c))
    
    ; the limitation of the control region boundary
    (define CONTROL-BOUNDARY 2)
    ; this constant is only used during the circle is moving, which represents
    ; the initial center position of the cirle.
    (define CENTER center)
    
    ; get-bounds : -> BoundingBox
    ; Returns a list of coordinate representing a circle
    ; Startegy: Data decomposition on center : Posn
    (define/public (get-bounds) (list (- (posn-x center) radius)
                                      (- (posn-y center) radius)
                                      (+ (posn-x center) radius)
                                      (+ (posn-y center) radius)))
    
    ; handle-mouse : Coordinate Coordinate MouseEvent -> Circle%
    ; Returns the object of the class depending upon the mouse event
    ; Startegy: Data decomposition on e : MouseEvent
    (define/public (handle-mouse cx cy e) 
      (cond
        [(string=? e "button-down") (gesture-start cx cy)]
        [(string=? e "drag") (gesturing cx cy)]
        [(string=? e "button-up") (gesture-end cx cy)]))
    
    ; gesture-start : Coordinate Coordinate -> Circle%
    ; Returns a new circle or an error by checking the state of the object
    ; Strategy: Data decomposition on state: ShapeState
    (define (gesture-start cx cy)
      (cond
        [(or (moving? state) (resizing? state) (creating? state)) 
         (build/c (make-posn cx cy) 0 state VS)]
        [(created? state) (init/resize/move cx cy)]))
    
    ; init/resize/move : Coordinate Coordinate -> Circle%
    ; Init resizing or moving a new circle depending on the current state of 
    ; object
    (define (init/resize/move cx cy)
      (local((define controlable (controlable? cx cy)))
        (if controlable
            (init-resize cx cy)
            (if (inside/this? cx cy)
                (init-move cx cy)
                this))))
    
    ; controlable? : Coordinate Coordinate -> Boolean
    ; Returns true if the mouse click is within the control boundary
    ; Strategy: Function composition
    (define (controlable? cx cy)
      (<= (- radius CONTROL-BOUNDARY) 
          (radius-now cx cy) 
          (+ radius CONTROL-BOUNDARY)))
    
    ; inside/this? : Coordinate Coordinate -> Boolean
    ; Returns true if the mouse click is inside the circle
    ; Strategy: Function composition
    (define (inside/this? cx cy)
      (< (radius-now cx cy) radius))
    
    ; init-resize : Coordinate Coordinate -> Circle% 
    ; Returns a new resized circle by changing the radius
    ; Strategy: Function composition
    (define (init-resize cx cy)
      (build/c center (radius-now cx cy) resizing VS))
    
    ; init-move : Coordinate Coordinate -> Circle% 
    ; Returns a new moved circle by changing the vector position
    ; Strategy: Function composition
    (define (init-move cx cy)
      (build/c center radius moving (make-posn cx cy)))
    
    ; gesturing : Coordinate Coordinate -> Circle%
    ; Returns a new circle based on the state of the circle
    ; Strategy: Data decomposition on state: ShapeState
    (define (gesturing cx cy)
      (cond
        [(or (resizing? state) (creating? state)) 
         (build/c center (radius-now cx cy) state VS)]
        [(moving? state) (add/vector cx cy)]
        [(created? state) this]))
    
    ; gesture-end : Coordinate Coordinate -> Circle%
    ; Returns a new circle with state as created
    ; Strategy: Function composition
    (define (gesture-end cx cy)
      (build/c center radius created v/s))
    
    ; add/vector : Coordinate Coordinate -> Circle%
    ; Returns the current cirlce with center updated according to the 
    ; coordinates passed and initial center posn.
    ; Startegy: Data decomposition on stable, dynamic : Posn
    (define (add/vector cx cy)
      (local((define vx (- cx (posn-x v/s)))
             (define vy (- cy (posn-y v/s)))
             (define v (set-center (make-posn (+ (posn-x CENTER) vx)
                                              (+ (posn-y CENTER) vy)))))
        this))
    
    ; radius-now : Coordinate Coordinate -> PosInt
    ; Returns the radius of circle by calculating the value from the center
    ; and the current mouse position
    ; Strategy: Data decomposition on center : Posn
    (define (radius-now cx cy)
      (sqrt (+ (sqr (- cx (posn-x center))) (sqr (- cy (posn-y center))))))
    
    ; draw : -> Image
    ; Returns an image of the circle
    ; Strategy: data decompostion on state: ShapeState
    (define/public (draw)
      (cond
        [(string=? creating state) (circle radius 127 "red")]
        [else (circle radius "outline" "black")]))
    
    ; get-centerX : -> Coordinate
    ; Returns the x coordinate of the center of the circle
    ; Strategy: Data decomposition on center : Posn
    (define/public (get-centerX) 
      (posn-x center))
    
    ; get-centerY : -> Coordinate
    ; Returns the y coordinate of the center of the circle
    ; Strategy: Data decomposition on center : Posn
    (define/public (get-centerY) 
      (posn-y center))
 
    ; testing:get-center: -> Posn
    (define/public (testing:get-center)
      center)
    
    ; testing:get-radius: -> Integer
    (define/public (testing:get-radius)
      radius)
    
    ; testing:get-state: -> ShapeState
    (define/public (testing:get-state)
      state)
    
    ; testing:get-vs: -> Posn
    (define/public (testing:get-vs)
      v/s)
    
    (super-new)))

; A World is a 
; make-world(ListOf<Shape<%>> DrawState Boolean)
; INTERP: shapes represents all the shapes in the current world, state represent
; the DrawState of the current world, stop-working represents whether the 
; current world is stop working
(define-struct world (shapes state stop-working?))
; INITIAL-WORLD : World
; An initial world, with no Shape<%>s.
(define INITIAL-WORLD (make-world '() pointer #false))

; Data examples:
(define posn1 (make-posn 50 50))
(define posn2 (make-posn 200 200))
(define rec1 
  (new Rectangle% [stable posn1] [dynamic posn2] [state created] [v/s VS]))
(define rec2 
  (new Rectangle% [stable posn1] [dynamic posn2] [state creating] [v/s VS]))
(define rec3 
  (new Rectangle% [stable posn1] [dynamic posn2] [state moving] [v/s VS]))
(define rec4 
  (new Rectangle% [stable posn1] [dynamic posn2] [state resizing] [v/s VS]))
(define cir0 
  (new Circle% [center POSN] [radius 0] [state created] [v/s VS]))
(define cir1 
  (new Circle% [center posn1] [radius 200] [state created] [v/s VS]))
(define cir2 
  (new Circle% [center posn1] [radius 200] [state creating] [v/s VS]))
(define cir3 
  (new Circle% [center posn1] [radius 200] [state moving] [v/s VS]))
(define cir4 
  (new Circle% [center posn1] [radius 200] [state resizing] [v/s VS]))

(define world1 (make-world (list cir0) pointer #false))
(define world2 (make-world (list cir1) pointer #true))
(define world3 (make-world (list cir1 cir2 cir3 cir4 
                                 rec1 rec2 rec3 rec4) pointer #false))
(define world4 (make-world (list cir1 cir2 cir3 cir4 
                                 rec1 rec2 rec3 rec4) rec #false))
(define world5 (make-world (list cir1 cir2 cir3 cir4 
                                 rec1 rec2 rec3 rec4) cir #false))

; build/r : Posn Posn ShapeState Posn -> Rectangle%
; Returns a new object of rectangle class
; Strategy: Function compostion
(begin-for-test
  (check-true (object? (build/r POSN POSN created VS))))
(define (build/r s d state vs)
  (new Rectangle% [stable s] [dynamic d] [state state] [v/s vs]))

; build/c : Posn PosInt ShapeState Posn -> Circle%
; Returns a new object of circle class
; Strategy: Function compostion
(begin-for-test
  (check-true (object? (build/c POSN 1 created VS))))
(define (build/c cntr r s vs)
  (new Circle% [center cntr] [radius r] [state s] [v/s vs]))

; draw-world : World -> Image
; Returns an image consisting of the draw area and toolbar
; Strategy: Function composition
(begin-for-test
  (check-equal? (draw-world (make-world '() pointer #false))
                (overlay/align "left" "top" 
                               (above (overlay WHITE-P BLACK-SQUARE)
                                       (overlay BLACK-R WHITE-SQUARE)
                                       (overlay BLACK-C WHITE-SQUARE))
                               MT)
                "Test failed. Function should return image of empty scene with 
toolbar and pointer selected")
  (check-equal? (draw-world (make-world '() rec #false))
                (overlay/align "left" "top" 
                               (above (overlay BLACK-P WHITE-SQUARE)
                                         (overlay WHITE-R BLACK-SQUARE)
                                         (overlay BLACK-C WHITE-SQUARE))
                               MT)
                "Test failed. Function should return image of empty scene with 
toolbar and rectangle selected")
  (check-equal? (draw-world (make-world '() cir #false))
                (overlay/align "left" "top" 
                               (above (overlay BLACK-P WHITE-SQUARE)
                                      (overlay BLACK-R WHITE-SQUARE)
                                      (overlay WHITE-C BLACK-SQUARE))
                               MT)
                "Test failed. Function should return image of empty scene with 
toolbar and circle selected"))
(define (draw-world w)
  (overlay/align "left" "top"
                 (draw-toolbar w)
                 (draw-all-shapes w)))

; draw-toolbar: World -> Image
; Draws different toolbar states based on the current world's state.
; Strategy: Data decomposition on w : World
(begin-for-test
  (check-equal? (draw-toolbar INITIAL-WORLD)
                (above (overlay WHITE-P BLACK-SQUARE)
                       (overlay BLACK-R WHITE-SQUARE)
                       (overlay BLACK-C WHITE-SQUARE))))
(define (draw-toolbar w)
  (cond
    [(pointer? (world-state w)) (above (overlay WHITE-P BLACK-SQUARE)
                                       (overlay BLACK-R WHITE-SQUARE)
                                       (overlay BLACK-C WHITE-SQUARE))]
    [(rectangle? (world-state w)) (above (overlay BLACK-P WHITE-SQUARE)
                                         (overlay WHITE-R BLACK-SQUARE)
                                         (overlay BLACK-C WHITE-SQUARE))]
    [(circle? (world-state w)) (above (overlay BLACK-P WHITE-SQUARE)
                                      (overlay BLACK-R WHITE-SQUARE)
                                      (overlay WHITE-C BLACK-SQUARE))]))

; draw-all-shapes : World -> Image
; Draws all the shapes in the current world.
; Strategy: Function composition
(begin-for-test
  (check-equal? (draw-all-shapes world1)
                MT))
(define (draw-all-shapes w)
  (foldr (lambda (s image) (place-image (send s draw)
                                        (send s get-centerX)
                                        (send s get-centerY)
                                        image))
         MT
         (world-shapes w)))

; handle-mouse : World Coordinate Coordinate MouseEvent -> World
; GIVEN: A World, mouse coordinates, and a MouseEvent
; RETURNS: A new World, like the given one, updated to reflect the action of
;    the mouse event, in the ways specified in the problem set.
; Strategy: Data decomposition on e : MouseEvent
(begin-for-test
  (check-equal? (handle-mouse world1 15 15 "move")
                world1
                "Test failed. Function should return a new world")
  (check-equal? (handle-mouse world1 15 15 "enter")
                world1
                "Test failed. Function should return a new world")
  (check-equal? (handle-mouse world1 15 15 "leave")
                world1
                "Test failed. Function should return a new world")
  (check-true (world? (handle-mouse world2 15 15 "button-up"))
                "Test failed. Function should return a new world")
  (check-true (world? (handle-mouse world1 15 15 "button-down"))
                "Test failed. Function should return a new world"))
(define (handle-mouse w c1 c2 e)
  (cond
    [(or (string=? e "move") (string=? e "enter") (string=? e "leave")) w]
    [else (if (world-stop-working? w)
              (handle-stop-working w e)
              (handle-world w c1 c2 e))]))

; handle-stop-working : World MouseEvent -> World
; Returns a world with world working as true or false 
; depending on mopuse event.
; Strategy: Data decomposition on e : MouseEvent
(begin-for-test
  (check-true (world? (handle-stop-working world2 "button-up"))
                "Test failed. Function should return a new world")
  (check-true (world? (handle-stop-working world2 "button-down"))
                "Test failed. Function should return a new world"))
(define (handle-stop-working w e)
  (cond
    [(string=? "button-up" e) 
     (make-world (world-shapes w) (world-state w) #false)]
    [else w]))

; handle-world : World Coordinate Coordinate MouseEvent -> World
; Returns a world by checking if mouse click is on toolbar or draw area
; Strategy: Data decomposition on e: MouseEvent
(begin-for-test
  (check-true (world? (handle-world world1 10 10 "button-down")))
  (check-true (world? (handle-world world1 100 100 "button-down"))))
(define (handle-world w c1 c2 e)
  (if (inside/toolbar? c1 c2) 
      (handle-toolbar w c1 c2 e)
      (handle-shapes w c1 c2 e)))

; inside/toolbar?: Coordinate Coordinate -> Boolean
; Returns true if the click is within toolbar area.
; Strategy: Function composition
(define (inside/toolbar? c1 c2)
  (and (<= TOOLBAR-LEFT c1 TOOLBAR-RIGHT) 
           (<= TOOLBAR-TOP c2 TOOLBAR-BOTTOM)))

; handle-toolbar : World Coordinate Coordinate MouseEvent -> World
; Returns a world with a tool selected from toolbar depending upon the 
; mouse event and moiuse position
; Strategy: Data decomposition on e : MouseEvent
(begin-for-test
  (check-true (world? (handle-world world1 10 10 "drag")))
  (check-true (world? (handle-world world1 10 10 "button-up"))))
(define (handle-toolbar w c1 c2 e)
  (cond 
    [(string=? "drag" e) 
     (make-world (world-shapes w) (world-state w) #true)]
    [(string=? "button-up" e)
     (make-world (world-shapes w) (next-state c1 c2) #false)]
    [else w]))

; next-state : Coordinate Coordinate -> DrawState
; GIVEN: A World, mouse coordinates, and a MouseEvent
; RETURNS: A new World, like the given one, updated to reflect the action of
;    the mouse event, in the ways specified in the problem set.
(begin-for-test
  (check-equal? (next-state 5 5) pointer 
                "Test failed. Function should return a pointer")
  (check-equal? (next-state 5 25) rec 
                "Test failed. Function should return a rectangle")
  (check-equal? (next-state 5 45) cir 
                "Test failed. Function should return a circle")) 
(define (next-state c1 c2)
  (if (and (<= TOOLBAR-LEFT c1 TOOLBAR-RIGHT) 
           (<= TOOLBAR-TOP c2 BETWEEN/P/R))
      pointer
      (if (and (<= TOOLBAR-LEFT c1 TOOLBAR-RIGHT) 
               (<= BETWEEN/P/R c2 BETWEEN/R/C))
          rec
          cir)))

; handle-shapes : World Coordinate Coordinate MouseEvent -> World
; Computes next world state based on the current and the mouse event
; Strategy: Data decompostion on w : World
(begin-for-test
  (check-true (world? (handle-shapes world3 0 0 "drag")))
  (check-true (world? (handle-shapes world3 0 0 "button-up")))
  (check-true (world? (handle-shapes world3 0 0 "button-down")))
  (check-true (world? (handle-shapes world4 0 0 "drag")))
  (check-true (world? (handle-shapes world4 0 0 "button-up")))
  (check-true (world? (handle-shapes world4 0 0 "button-down")))
  (check-true (world? (handle-shapes world5 0 0 "drag")))
  (check-true (world? (handle-shapes world5 0 0 "button-up")))
  (check-true (world? (handle-shapes world5 0 0 "button-down"))))
(define (handle-shapes w c1 c2 e)
  (cond 
    [(pointer? (world-state w)) 
     (make-world (handle-pointer (world-shapes w) c1 c2 e) pointer #false)]
    [(rectangle? (world-state w)) 
     (make-world (handle-draw (world-shapes w) c1 c2 e 
                              (build/r POSN POSN creating VS)) 
                 rec #false)]
    [(circle? (world-state w)) 
     (make-world (handle-draw (world-shapes w) c1 c2 e 
                              (build/c POSN 0 creating VS))
                 cir #false)]))

(define (handle-pointer shapes c1 c2 e)
  (modify c1 c2 e shapes))

; handle-draw : ListOf<Shape<%>> Coordinate Coordinate MouseEvent Shape<%> -> 
; ListOf<Shape<%>>
; Returns all the shapes of the world after a mouse event intented to draw
; a new shape
; Strategy: Function composition
(begin-for-test
  (check-true 
   (list? (handle-draw '() 100 100 "button-down" 
                       (new Circle% [center POSN] [radius 0] [state creating]
                            [v/s VS])))))
(define (handle-draw shapes c1 c2 e new-instance)
  (local((define creating-shapes (filter-creating shapes)))
    (append (modify c1 c2 e (if (empty? creating-shapes) 
                                (list new-instance)
                                creating-shapes))
            (filter-created shapes))))

; filter-creating: ListOf<Shape<%>> -> ListOf<Shape<%>>
; Returns the those shapes in the current world whose state is creating
; Strategy: Function composition
(begin-for-test
  (check-equal? (filter-creating (list rec1 rec2))
                (list rec2)))
(define (filter-creating shapes)
  (filter (lambda (s) (creating? (get-field state s)))
          shapes))

; filter-created ListOf<Shape<%>> -> ListOf<Shape<%>>
; Returns the those shapes in the current world whose state is created
; Strategy: Function composition
(begin-for-test
  (check-equal? (filter-created (list rec1 rec2))
                (list rec1)))
(define (filter-created shapes)
  (filter (lambda (s) (created? (get-field state s)))
          shapes))

; modify: Coordinate Coordinate MouseEvent ListOf<Shape<%>> -> ListOf<Shape<%>>
; Computes new shapes based on the given click(c1, c2) and MouseEvent e
; Strategy: Function composition
(begin-for-test
  (check-true (list? (modify 100 100 "drag" (list rec1 rec2 rec3 rec4
                                                  cir1 cir2 cir3 cir4)))))
(define (modify c1 c2 e shapes)
  (map (lambda (s) (send s handle-mouse c1 c2 e))
       shapes))

; get-world-shapes : World -> ListOf<Shape<%>>
; GIVEN: A World,
; RETURNS: All the Shape<%>s which make up that world, i.e. all those that
;    have been created by the user through using the tools.
; Strategy: Function composition
(begin-for-test
  (check-equal? (get-world-shapes world1) 
                (list cir0)))
(define (get-world-shapes w) 
  (filter (lambda (s) (created? (get-field state s)))
          (world-shapes w)))

; create-circle : Posn Integer -> Shape<%>
; GIVEN: A center point and a radius
; RETURNS: A new Circle% object (implementing Shape<%>) with its center at
;    the given point and radius as given.
; Strategy: Function composition
(begin-for-test
  (check-true (object? (create-circle POSN 1))))
(define (create-circle pos r)
  (new Circle% 
       [center pos] 
       [radius r]
       [state creating]
       [v/s VS]))

; create-rectangle : BoundingBox -> Shape<%>
; GIVEN: A bounding box,
; RETURNS: A new Rectangle% object (implementing Shape<%>) which is bounded
;    by the given BoundingBox.
; Strategy: Function composition
(begin-for-test
  (check-true (object? (create-rectangle (list 1 2 3 4)))))
(define (create-rectangle b)
  (build/r (make-posn (first b) (second b))
           (make-posn (third b) (fourth b))
           created VS))

; run: World -> Image
; Computes next world state based on the current world state
; Strategy: function composition
(define (run w)
  (big-bang w
            (on-mouse handle-mouse)
            (to-draw draw-world)))

; Example for Testing
(define test-rectangle (new Rectangle% 
                            [stable (make-posn 10 10)]
                            [dynamic (make-posn 20 20)] 
                            [state "creating"] 
                            [v/s (make-posn 0 0)]))
(define test-resize-rectangle (new Rectangle% 
                            [stable (make-posn 10 10)] 
                            [dynamic (make-posn 50 50)] 
                            [state "created"] 
                            [v/s (make-posn 0 0)]))
(define test-move-rectangle (new Rectangle% 
                            [stable (make-posn 10 10)] 
                            [dynamic (make-posn 60 60)] 
                            [state "created"] 
                            [v/s (make-posn 0 0)]))
(define test-moving-rectangle (new Rectangle% 
                            [stable (make-posn 100 100)] 
                            [dynamic (make-posn 150 150)] 
                            [state "moving"] 
                            [v/s (make-posn 125 125)]))

(define DRAG-RECTANGLE (send test-rectangle handle-mouse 50 50 "drag"))
(define DRAG-RECTANGLE-EXPECTED (new Rectangle% 
                            [stable (make-posn 10 10)] 
                            [dynamic (make-posn 50 50)] 
                            [state "creating"] 
                            [v/s (make-posn 0 0)]))
(define BUTTON-UP-RECTANGLE (send test-resize-rectangle handle-mouse 50 50 
                                  "button-down"))
(define BUTTON-UP-RECTANGLE-EXPECTED (new Rectangle% 
                            [stable (make-posn 10 10)] 
                            [dynamic (make-posn 50 50)] 
                            [state "resizing"]
                            [v/s (make-posn 0 0)]))
(define BUTTON-DOWN-RECTANGLE (send test-resize-rectangle handle-mouse 80 80 
                                  "button-up"))
(define BUTTON-DOWN-RECTANGLE-EXPECTED (new Rectangle% 
                            [stable (make-posn 10 10)] 
                            [dynamic (make-posn 50 50)] 
                            [state "created"] 
                            [v/s (make-posn 0 0)]))
(define BUTTON-UP-REC-MOVE (send test-resize-rectangle handle-mouse 30 30 
                                  "button-down"))
(define BUTTON-UP-REC-MOVE-EXPECTED (new Rectangle% 
                            [stable (make-posn 10 10)] 
                            [dynamic (make-posn 50 50)] 
                            [state "moving"] 
                            [v/s (make-posn 30 30)]))
(define CREATING-RECTANGLE (send test-rectangle handle-mouse 50 50 
                                 "button-down"))
(define CREATING-RECTANGLE-EXPECTED (new Rectangle% 
                            [stable (make-posn 50 50)] 
                            [dynamic (make-posn 50 50)] 
                            [state "creating"] 
                            [v/s (make-posn 0 0)]))
(define MOVING-RECTANGLE (send test-moving-rectangle handle-mouse 200 200 
                                 "drag"))
(define MOVING-RECTANGLE-EXPECTED (new Rectangle% 
                            [stable (make-posn 175 175)] 
                            [dynamic (make-posn 225 225)] 
                            [state "moving"] 
                            [v/s (make-posn 125 125)]))
(define INVALID-MOUSE-INPUT (send test-rectangle handle-mouse 200 200 
                                 "xyz"))
(define INVALID-MOUSE-INPUT-EXPECTED (new Rectangle% 
                            [stable (make-posn 10 10)] 
                            [dynamic (make-posn 20 20)] 
                            [state "creating"] 
                            [v/s (make-posn 0 0)]))

(begin-for-test
  (check-equal? (send rec1 get-bounds)
                '(50 50 200 200))
  (check-equal? (send cir1 get-bounds)
                '(-150 -150 250 250)))  

(define (rectangle-equal? r1 r2)
  (and
   (equal?
    (send r1 testing:get-stable)
    (send r2 testing:get-stable))
   (equal?
    (send r1 testing:get-dynamic)
    (send r2 testing:get-dynamic))
   (equal?
    (send r1 testing:get-state)
    (send r2 testing:get-state))
   (equal?
    (send r1 testing:get-vs)
    (send r2 testing:get-vs))
   (equal?
    (send r1 draw)
    (send r2 draw))
   (equal?
    (send r1 get-bounds)
    (send r2 get-bounds)))
   )
(begin-for-test
  (check rectangle-equal? DRAG-RECTANGLE DRAG-RECTANGLE-EXPECTED
         "Test failed. Draging test failed for rectangle")
  (check rectangle-equal? BUTTON-UP-RECTANGLE BUTTON-UP-RECTANGLE-EXPECTED
         "Test failed. Resizing test failed for rectangle")
  (check rectangle-equal? BUTTON-DOWN-RECTANGLE BUTTON-DOWN-RECTANGLE-EXPECTED
         "Test failed. Creating test failed for rectangle")
  (check rectangle-equal? BUTTON-UP-REC-MOVE BUTTON-UP-REC-MOVE-EXPECTED
         "Test failed. Moving test failed for rectangle")
  (check rectangle-equal? CREATING-RECTANGLE CREATING-RECTANGLE-EXPECTED
         "Test failed. Creating new test failed for rectangle")
  (check rectangle-equal? MOVING-RECTANGLE MOVING-RECTANGLE-EXPECTED
         "Test failed. Drag and Moving new test failed for rectangle")
  (check rectangle-equal? INVALID-MOUSE-INPUT INVALID-MOUSE-INPUT-EXPECTED
         "Test failed. Drag and Moving new test failed for rectangle"))

; Example of circle for testing
(define test-circle (new Circle% 
                            [center (make-posn 100 100)] 
                            [radius 0] 
                            [state "creating"] 
                            [v/s (make-posn 0 0)]))
(define test-moving-circle (new Circle% 
                            [center (make-posn 100 100)] 
                            [radius 100] 
                            [state "moving"] 
                            [v/s (make-posn 100 100)]))
(define test-created-circle (new Circle% 
                            [center (make-posn 100 100)] 
                            [radius 100] 
                            [state "created"] 
                            [v/s (make-posn 100 100)]))
(define test-created-bd-circle (new Circle% 
                            [center (make-posn 100 100)] 
                            [radius 100] 
                            [state "created"] 
                            [v/s (make-posn 100 100)]))

(define DRAG-CIRCLE (send test-circle handle-mouse 200 100 "drag"))
(define DRAG-CIRCLE-EXPECTED (new Circle% 
                            [center (make-posn 100 100)] 
                            [radius 100] 
                            [state "creating"] 
                            [v/s (make-posn 0 0)]))
(define MOVING-CIRCLE (send test-moving-circle handle-mouse 200 100 "drag"))
(define MOVING-CIRCLE-EXPECTED (new Circle% 
                            [center (make-posn 200 100)] 
                            [radius 100] 
                            [state "moving"] 
                            [v/s (make-posn 100 100)]))
(define CREATED-CIRCLE (send test-created-circle handle-mouse 200 100 "drag"))
(define CREATED-CIRCLE-EXPECTED (new Circle% 
                            [center (make-posn 100 100)] 
                            [radius 100] 
                            [state "created"] 
                            [v/s (make-posn 100 100)]))
(define BD-CREATING-CIRCLE (send test-circle handle-mouse 200 100 
                                 "button-down"))
(define BD-CREATING-CIRCLE-EXPECTED (new Circle% 
                            [center (make-posn 200 100)] 
                            [radius 0] 
                            [state "creating"] 
                            [v/s (make-posn 0 0)]))
(define BD-CREATED-CIRCLE (send test-created-bd-circle handle-mouse 198 100 
                                 "button-down"))
(define BD-CREATED-CIRCLE-EXPECTED (new Circle% 
                            [center (make-posn 100 100)] 
                            [radius 98] 
                            [state "resizing"] 
                            [v/s (make-posn 100 100)]))

(define (circle-equal? r1 r2)
  (and
   (equal?
    (send r1 testing:get-center)
    (send r2 testing:get-center))
   (equal?
    (send r1 testing:get-radius)
    (send r2 testing:get-radius))
   (equal?
    (send r1 testing:get-state)
    (send r2 testing:get-state))
   (equal?
    (send r1 testing:get-vs)
    (send r2 testing:get-vs))
   (equal?
    (send r1 draw)
    (send r2 draw))
   (equal?
    (send r1 get-bounds)
    (send r2 get-bounds))))
(begin-for-test
  (check circle-equal? DRAG-CIRCLE DRAG-CIRCLE-EXPECTED
         "Test failed. Dragging new circle test failed.")
  (check circle-equal? MOVING-CIRCLE MOVING-CIRCLE-EXPECTED
         "Test failed. Moving circle test failed.")
  (check circle-equal? CREATED-CIRCLE CREATED-CIRCLE-EXPECTED
         "Test failed. Created circle test failed.")
  (check circle-equal? BD-CREATING-CIRCLE BD-CREATING-CIRCLE-EXPECTED
         "Test failed. Creating new circle test failed."))