    
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

section .rodata
    format_targetX:      db "%.2f,",0,0
    format_targetY:      db "%.2f",10,0
    fromat_id:       db "%d, ",0,0
    fromat_fl:       db "%.2f,",0,0
    fromat_score:       db "%d",10,0

section .data
    extern DRONES_ARR
    extern DRO_NUM
    extern SCHEDULER_CO
    global PRINT_CO

    PRINT_CO:     dd print_tar
                  dd PRT_ST+STKSZ
    
section .bss
    PRT_ST:     resb STKSZ
    
    extern CORX_TARGET
    extern CORY_TARGET

section .text
    align 16
    extern printf
    extern resume

print_tar:
    finit
    pushad
    fld     dword[CORX_TARGET] 
    sub     esp,8  
    fstp    qword[esp]  
    push    format_targetX   
    call    printf
    add     esp,12
    popad
    pushad
    fld     dword[CORY_TARGET]
    sub     esp,8  
    fstp    qword[esp]  
    push    format_targetY   
    call    printf
    add     esp,12
    popad
  

.print_drone:
    mov     ebx,[DRONES_ARR]            
    mov     eax,1
.p1:
    cmp     eax,dword[DRO_NUM]             
    ja     .change
    cmp     dword[ebx+ACTIVE],1
    je      .p2    
    add     ebx,DRONE_SIZE             ; advances to next drone to print 
    inc     eax 
    jmp     .p1
 .change:                    
    mov     ebx,SCHEDULER_CO              ; returns back to scheduler after printing
    call    resume
    jmp     print_tar
.p2:
    pushad
    push    eax
    push fromat_id
    call printf
    add esp,8

    sub     esp,8
    finit
    fld    dword[ebx+CORDINATA_X]     ; push all values of the state of each drone and then print it 
    fstp    qword[esp]                    ;converts floats to doubles   
    push    fromat_fl
    call    printf
    add     esp,12

    sub     esp,8
    fld    dword[ebx+CORDINATA_Y]     ; push all values of the state of each drone and then print it 
    fstp    qword[esp]                    ;converts floats to doubles   
    push    fromat_fl
    call    printf
    add     esp,12

    sub     esp,8
    fld    dword[ebx+ANGLE]     ; push all values of the state of each drone and then print it 
    fstp    qword[esp]                    ;converts floats to doubles   
    push    fromat_fl
    call    printf
    add     esp,12

    sub     esp,8
    fld    dword[ebx+SPEED]     ; push all values of the state of each drone and then print it 
    fstp    qword[esp]                    ;converts floats to doubles   
    push    fromat_fl
    call    printf
    add     esp,12

    push    dword[ebx+SCORE]
    push fromat_score
    call printf
    add esp,8

    popad
    add     ebx,DRONE_SIZE             ; advances to next drone to print 
    inc     eax
    jmp     .p1