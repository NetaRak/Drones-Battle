    
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
    global mayDestroy
    global CO_TARGET
        tmp:     dd 0.0

    
    CO_TARGET:     dd TARGET_CONTINUE
                   dd TARGET_STACK+STKSZ
    
    extern SCHEDULER_CO
        
section .bss
    global CORX_TARGET
    global CORY_TARGET
    
    TARGET_STACK:     resb STKSZ
    CORX_TARGET:      resd 1
    CORY_TARGET:      resd 1
    
section .text
    align 16
    extern generateRandom
    extern resume
    global createTarget
    extern printf
    extern MAX_DIS


TARGET_CONTINUE:
    call    createTarget
    mov     ebx,SCHEDULER_CO
    call    resume              ; call to scheduler after creating a target
    jmp     TARGET_CONTINUE
    

createTarget:
    push    dword 0             ; initialize [0,100] scale for get random points to target
    push    dword 100           
    call    generateRandom
    mov     [CORX_TARGET],esi   ; stores in TAR_XPOS and in TAR_YPOS random points
    add     esp,8
    push    dword 0             ; initialize [0,100] scale for get random points to target
    push    dword 100 
    call    generateRandom
    mov     [CORY_TARGET],esi
    add     esp,8
    ret


  
mayDestroy:
    finit
    fld     dword[CORX_TARGET]             ;load cordinata x of target
    fsub    dword[edi+eax+CORDINATA_X]     ;calculate :x_tar - x_currDrone
    fst     dword[tmp] 
    fmul    dword[tmp]                     ;calculate:(x_tar - x_currDrone)*(x_tar - x_currDrone)
    fld     dword[CORY_TARGET]             ;load cordinata y of target
    fsub    dword[edi+eax+CORDINATA_Y]     ;calculate :y_tar - y_currDrone
    fst     dword[tmp]
    fmul    dword[tmp]                     ;calculate:(y_tar - y_currDrone)*(y_tar - y_currDrone)
    faddp                                  ;calculate sqrt((y_tar - y_currDrone)^2+(x_tar - x_currDrone)^2)
    fsqrt                                  ;calculate the square root of the contents of a floating- point register== the distance between target to currDrone
    fld     dword[MAX_DIS]                 ;load MAX_DIS between target to Drone
    fcomip                                 ;compares between MAX_DIS to the distance between target to currDrone
    jna     .notCloseEnough
    mov     ebx,1
    ret
.notCloseEnough:
    mov     ebx,0
    ret


     
