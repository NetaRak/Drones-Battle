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
    scan_int:        dd "%d",0
    scan_flot:       dd "%f",0
    max_short:        dd 0x0000FFFF
    ;fromat_id:       db "why ? %.2f, ",10,0

    
section .data
    global CORS_ARR
    global DRONES_ARR
    global CURR
    global DRO_NUM
    global ROUND_ELIM
    global K_STEPS
    global MAX_DIS
    global end
    extern PRINT_CO
    extern SCHEDULER_CO
    extern CO_TARGET

    DRO_NUM:         dd 0       ;arg[1]- num of drons
    ROUND_ELIM:     dd 0       ;arg[2]- number of full scheduler cycles between each elimination 
    K_STEPS:        dd 0       ;arg[3]- how many drone steps between game board printings 
    MAX_DIS:        dd 0       ;arg[4]- maximum distance that allows to destroy a target
    SEED:           dd 0       ;arg[5]- seed for initialization of LFSR shift register
    SEED_COPY:      dd 0
    STACKS_ARR:     dd 0       ;saves pointers to the start of the drone co-routine's stacks
    CORS_ARR:       dd 0       ;drone co-routines array
    DRONES_ARR:     dd 0       ;drone information array
    START_ADRESS:   dd 0
    SPT:            dd 0
    CURR:           dd 0
    bit_16:         dd 0
    bit_14:         dd 0
    bit_13:         dd 0
    bit_11:         dd 0
    h:              dd 120.0
    z:              dd 0.0
    six:            dd 60.0
    random_res:     dd 0
    
section .bss
    extern CORX_TARGET
    extern CORY_TARGET
       

    
section .text
    align 16
    global main
    global generateRandom
    global resume
    global end
    extern sscanf
    extern calloc
    extern free
    extern printf
    extern loop1
    extern createTarget


%macro scan_commend_line 0                 ;macro for sscanf stdlib function to get command line arguments 
        pushad
        push    DRO_NUM           ;   the arg label 
        push    scan_int          ;   type of format we wish to get the argument
        push    dword [eax]       ;   arg[1]- num of drons
        call    sscanf 
        add     esp,12            
        popad
        add     eax,4

        pushad
        push    ROUND_ELIM        ;   the arg label 
        push    scan_int          ;   type of format we wish to get the argument
        push    dword [eax]       ;   arg[2]- number of full scheduler cycles between each elimination
        call    sscanf 
        add     esp,12            ;   clean stack
        popad
        add     eax,4

        pushad
        push    K_STEPS           ;   the arg label 
        push    scan_int          ;   type of format we wish to get the argument
        push    dword [eax]       ;   arg[3]- how many drone steps between game board printings
        call    sscanf 
        add     esp,12            ;   clean stack
        popad
        add     eax,4

        pushad
        push    MAX_DIS           ;   the arg label 
        push    scan_flot         ;   type of format we wish to get the argument
        push    dword [eax]       ;   arg[4]- maximum distance that allows to destroy a target
        call    sscanf 
        add     esp,12            ; clean stack
        popad
        add     eax,4

        pushad
        push    SEED              ;   the arg label 
        push   scan_int
        push    dword [eax]       ;   arg[5]- seed for initialization of LFSR shift register
        call    sscanf 
        add     esp,12            ;   clean stack
        popad
        add     eax,4
        
    %endmacro

%macro  init_arrays 0     ; macro for allocating array in memorry
        mov     eax,[DRO_NUM] 
        mov     ebx,DRONE_SIZE      
        mul     ebx         
        allocate
        mov     [DRONES_ARR],eax  

        mov     eax,[DRO_NUM] 
        mov     ebx,CO_SIZE     
        mul     ebx         
        allocate
        mov     [CORS_ARR],eax  

        mov     eax,[DRO_NUM] 
        mov     ebx,4     
        mul     ebx         
        allocate
        mov     [STACKS_ARR],eax

    %endmacro

%macro free_CORS_ARR 0          
        pushad
        push    dword [CORS_ARR]  
        call    free
        add     esp,4
        popad
    %endmacro

%macro free_DRONES_ARR 0        
        pushad
        push    dword [DRONES_ARR]  
        call    free
        add     esp,4
        popad
    %endmacro

%macro free_STACKS_ARR 0         
        pushad
        push    dword [STACKS_ARR ]  
        call    free
        add     esp,4
        popad
    %endmacro

%macro allocate 0       ; macro for allcoate space in memory 
        sub     esp,4       
        pushad
        push 1
        push    eax            
        call    calloc
        add     esp,8      
        mov     [esp+32],eax 
        popad
        pop     eax         
    %endmacro
;==========================================================================================

main:                    
    mov     eax,[esp]                   ; save return address to _start
    mov     [START_ADRESS],eax
    mov     eax,[esp+8]     
    add     eax,4                       ; eax holds argv[1]
    scan_commend_line                        
    init_arrays                         ; using makeArray macro described above
    call    createTarget  
init_main:
    mov     ebx,0
    mov     edx,0
    mov     ebp,0
    mov     ecx,0                       ; edi count-number of drones
    mov     edx,[DRONES_ARR]            ; edx holds the pointer to the first drone detailes
    mov     ebp,[STACKS_ARR]            ; ebp holds the pointer to the stack of the co-routine
    mov     ebx,[CORS_ARR]              ; ebx holds the pointer to the first co-routine

.drones2Co_routines:                    ; initializes drone's detailes and co-routines
    cmp     ecx,[DRO_NUM]                ; compare the counter to N -number of drones
    je      .restCo_routines            
    mov     dword [ebx+CODEP],loop1      ; save the adress of function play in the area memory of the co-routine
    mov     eax,STKSZ
    allocate                            ; allcoates stack for co-routine
    mov     [ebp+4*ecx],eax             ; stores the pointer to the stack
    add     eax,STKSZ                   ; points to top of stack
    mov     [ebx+SPP],eax               ; stores the stack pointer at the co-routine
    call    co_init                     ; initializes the co-routine
    push    dword 0                     ; initialize generateRandomb with [0,100] and generates X,Y
    push    dword 100
 
    call    generateRandom
    mov     [edx+CORDINATA_X],esi       ; esi holds the random number so we store in the current drone the D_XPOS/D_YPOS/D_ANG random value 
    add esp,8
    push    dword 0                     ; initialize generateRandomb with [0,100] and generates X,Y
    push    dword 100
    call    generateRandom
    mov     [edx+CORDINATA_Y],esi
    add     esp,8
    push    dword 0                     ; initialize generateRandomb with [0,100] and generates X,Y
    push    dword 100
    call    generateRandom
    mov     [edx+SPEED],esi
    add     esp,8
    push    dword 0
    push    dword 360
    call    generateRandom
    add     esp,8
    mov     [edx+ANGLE],esi 
    mov     dword[edx+SCORE],0          ; score - 0 
    mov     dword[edx+ACTIVE],1         ; active - 0 
    add     ebx,CO_SIZE                 ; moves to next co-routine
    inc     ecx                         ; counterDrones++ 
    add     edx,DRONE_SIZE              ; move to next drone  
    jmp     .drones2Co_routines

.restCo_routines:  
    mov     ebx,PRINT_CO                ; initialize the co-routine of the printer
    call    co_init         
    mov     ebx,CO_TARGET               ; initialize the co-routine of the targets
    call    co_init
    mov     ebx,SCHEDULER_CO            ; initialize the co-routine of the scheduler
    call    co_init
    jmp     do_resume   



co_init:    ;create initial co-routines state
    pushad                         
    mov     eax,[ebx+CODEP]         ; get initial EIP value –pointer to COi function
    mov     [SPT],esp               ; save ESP value
    mov     esp,[ebx+SPP]           ; get initial ESP value –pointer to COi stack
    push    eax                     ; push initial “return” address
    pushfd                          ; push flags
    pushad                          ; push all other registers
    mov     [ebx+SPP],esp           ; save new SPi value (after all the pushes)
    mov     esp,[SPT]               ; restore ESP value
    popad
    ret
   
resume:     ; save state of current co-routine
    pushfd                          ; push flags
    pushad                          ; push all other registers
    mov     edx,[CURR]              
    mov     [edx+SPP],esp           ; save current ESP
do_resume:  ;load ESP for resumed co-routine
    mov     esp,[ebx+SPP]
    mov     [CURR],ebx
    popad                           ; restore resumed co-routine state
    popfd
    ret                             ; "return" to resumed co-routine

    
end:                        ; free memory and exits
    mov     ebx,[STACKS_ARR]    
    mov     ecx,0
    
.free_coR:
    cmp     ecx,[DRO_NUM]
    je      .free_the_arrays
    pushad
    push    dword [ebx]  
    call    free
    add     esp,4
    popad 
    add     ebx,4
    inc     ecx
    jmp     .free_coR
.free_the_arrays:  
    free_CORS_ARR               ; free the arrays
    free_DRONES_ARR  
    free_STACKS_ARR          
    mov     eax,0           ; return value 0 (succesful)
    jmp     [START_ADRESS]          ; returns to _start

generateRandom:
    sub     esp,4
    pushad
    mov     edi,16            ; shift the LFSR 16 times per call
.get_bit_loop:
        cmp edi, 0
        je scales
        mov ecx,[SEED]       
        mov edx,[SEED]          
        mov bl,cl 
        and bl,1
        mov byte[bit_16],bl 

        shr cx,2
        and cl,1
        mov byte[bit_14],cl
       
        shr cx,1
        and cl,1
        mov byte[bit_13],cl

        shr cx,2
        and cl,1
        mov byte[bit_11],cl
.calc_xor:
        mov al,byte[bit_16]
        mov bl,byte[bit_14]
        xor al,bl
        mov bl,byte[bit_13]
        xor al,bl
        mov bl,byte[bit_11]
        xor al,bl

        mov ecx,dword[SEED]
        shl ax,15
        shr cx,1
        add cx,ax
        mov dword[SEED], ecx
        dec edi
        jmp .get_bit_loop 
scales:
    finit
    fild    dword [SEED]        ; scales the random number with (b-a)*(random/MAX_INT)+a
    fidiv   dword [max_short]
    fild    dword [esp+40]
    fisub   dword [esp+44]
    fmulp
    fiadd   dword [esp+44]
    fstp    dword [esp+32]      ; stores result from FPU to saved space
    popad
    pop     esi                 ; pops result to esi
    ret 

    
 