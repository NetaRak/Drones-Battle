
   STKSZ         equ 16*1024              ;points to top of stack 
    CORDINATA_X   equ 0                    ;the current drone the X 
    CORDINATA_Y   equ 4                    ;the current drone the Y
    ANGLE         equ 8                    ;the current drone ANGLE 
    SCORE         equ 12                   ;the current drone SCORE 
    SPEED         equ 16                   ;the current drone SPEED
    ACTIVE        equ 20                   ;the current drone STATE 
    DRONE_SIZE    equ 24                   ;size of drone  
    CODEP	      equ 0	                   ;offset to co-routine function
    SPP        	  equ 4	                   ;offset to co-routine stack 
    CO_SIZE       equ 8                    ;size of co-routine 
    
section .data
    news:    dd 0.0
  
    newAn:   dd 0.0
  
    rad:     dd 180.0
  
    circ:    dd 360.0
  
    bord:    dd 100.0
  
    speed:   dd 100.0
    
    zero:    dd 0.0
  
    curr_sp: dd 0.0
    
    
    extern CORS_ARR
    extern DRONES_ARR
    extern CURR
    extern CO_TARGET
    extern targets
    extern printf
    extern SCHEDULER_CO
    extern MAX_DIS
    
section .bss
    
section .text
    align 16
    extern generateRandom
    extern resume
    global loop1
    extern printf
    extern mayDestroy

 
    %macro convertToRad 0        ; macro convert degree to radian->radians = degrees × π / 180°
        fldpi                    ; load pi-> π = 3.14 
        fdiv    dword[rad]       ; π / 180°
        fmulp                    ; st[0]degrees × π / 180°
    %endmacro


     %macro torusAngle 0               ; macro for wraparound a angle
            fldz
            fcomip               ; compares with 0
            fld     dword[circ]   ; %1 - loads max size
            jna     .greater_from_zero         ; skips if num>=0
            faddp                ; adds max size to num else
            fstp    dword[edi+eax+ANGLE]
            jmp .done
        .greater_from_zero:
            fcomi               ; compares with max size
            jnbe    .in_range       ; skips if num<max size
            fsubp               ; subtracts max size from num otherwise
            fstp    dword[edi+eax+ANGLE]
            jmp .done
        .in_range:
            fincstp             ; pops out max size from the FPU in case of skipping
        .load_ang:
            fstp    dword[edi+eax+ANGLE] ; stores wraparounded num at the given field %2
        .done:     
     %endmacro
    
    %macro getCurrDone 0
        mov eax,0
        mov edx,0
        mov ebx,0
        mov     eax,[CURR]               
        mov     edx,[CORS_ARR]          ; edx holds the co-routines array
        sub     eax,edx                 ; eax hold the offset to current co-routine co-routine
        mov     edx,0       
        mov     ebx,CO_SIZE
        div     ebx                     ; eax holds the current drone number
        mov     ebx,DRONE_SIZE 
        mul     ebx                     ; eax hold the offset to current drone's detailes
    %endmacro
    

%macro torusSpeed 0               ; macro for wraparound a drone's X,Y 
        fldz
        fcomip               ; compares with 0
        fld     dword[speed]   ; %1 - loads max size
        jna     r1         ; skips if num>=0
        fld     dword[zero]
        fstp    dword[edi+eax+SPEED]
        jmp     r2
     r1:
        fcomi              ; compares with max size
        ja    .r12       ; skips if num<max size
        fstp    dword[edi+eax+SPEED]
        jmp     r2
    .r12:
        fincstp             ; pops out max size from the FPU in case of skipping
        fstp    dword[edi+eax+SPEED]
    r2:

    %endmacro


loop1: 
    finit
    getCurrDone                   ;eax holds the current drone
    mov     edi,[DRONES_ARR]
    cmp     dword[edi+eax+ACTIVE],1
    jne     sch_co

; Generate random heading change angle  ∆α 
    push    dword -60               ; initialize [-60,60] scale for get random angel filed of view 
    push    dword 60
    call    generateRandom          ; generate a random number in range [-60,60] degrees, with 16 bit resolution
    add     esp,8
    mov     [newAn],esi
    
; Generate random speed change ∆a 
    push    dword -10
    push    dword 10
    call    generateRandom             ;generate random number in range [-10,10]- the resule in esi 
    add     esp,8
    mov     [news],esi

;------------------------------------------------------------
; Compute a new drone position as follows:
;first move speed units at the direction defined by the current angle, wrapping around the torus if needed.
   
    mov     edi,[DRONES_ARR]
    mov     ebx, dword[edi+eax+SPEED]
    mov     [curr_sp], ebx
    finit
    fld     dword[edi+eax+ANGLE]           
    convertToRad                            ; convert angle from dgree to radian 
    fsincos                                
;calculate speed*cos(ANGLE)+XPOS = the new X
    fmul    dword[curr_sp]             
    fadd    dword[edi+eax+CORDINATA_X]  
    call torusBordX
;calculate speed*sin(ANGLE)+YPOS = the new Y 
    fmul    dword[curr_sp]            
    fadd    dword[edi+eax+CORDINATA_Y]  
    call torusBordY                

;-------------------------------------------------------------------

; then change the current angle to be α + ∆α, keeping the angle between [0, 360] by wraparound if needed
    finit
    fld     dword [edi+eax+ANGLE]        ; load the adress of the ANG of the current drone 
    fadd    dword [newAn]                ; adds the random angle to current angle
    torusAngle                           ; wraparounds the new angle

;then change the current speed to be speed + ∆a, keeping the speed between [0, 100] by cutoff if needed
    finit
    fld     dword [edi+eax+SPEED]        ; load the adress of the SPEED of the current drone 
    fadd    dword [news]                 ; adds the random speed to current speed
    torusSpeed

.check_mayDestroy:
    call    mayDestroy                      ; check if a drone may destroy the target
    cmp     ebx,1                           ; cheks if mayDestroy returned true=1 
    jne     sch_co
    inc     dword[edi+eax+SCORE]            ; increement the score of the drone
.tar_co:
    mov     ebx,CO_TARGET                   ; calls target co-routine to create a new target
    jmp     other
sch_co:
    mov     ebx,SCHEDULER_CO                ; return to scheduler if false
other:
    call    resume
    jmp     loop1

;----------------------------------------------------------------------------
 
torusBordX:              ; macro for wraparound a drone's X,Y 
            fldz
            fcomip               ; compares with 0
            fld     dword[bord]   ; %1 - loads max size
            jna     check_100         ; skips if num>=0
            faddp                ; adds max size to num else
            fstp    dword[edi+eax+CORDINATA_X]
            jmp     after_ch
        check_100:
            fcomi               ; compares with max size
            jnbe    in_ran       ; skips if num<max size
            fsubp               ; subtracts max size from num otherwise
            fstp    dword[edi+eax+CORDINATA_X]
            jmp     after_ch
        in_ran:
            fincstp             ; pops out max size from the FPU in case of skipping
            fstp    dword[edi+eax+CORDINATA_X]
        after_ch:
    ret


    torusBordY:              ; macro for wraparound a drone's X,Y 
            fldz
            fcomip               ; compares with 0
            fld     dword[bord]   ; %1 - loads max size
            jna     check_100Y         ; skips if num>=0
            faddp                ; adds max size to num else
            fstp    dword[edi+eax+CORDINATA_Y]
            jmp     after_chY
        check_100Y:
            fcomi               ; compares with max size
            jnbe    in_ranY       ; skips if num<max size
            fsubp               ; subtracts max size from num otherwise
            fstp    dword[edi+eax+CORDINATA_Y]
            jmp     after_chY
        in_ranY:
            fincstp             ; pops out max size from the FPU in case of skipping
            fstp    dword[edi+eax+CORDINATA_Y]
        after_chY:
    ret