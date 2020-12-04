 
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
    winner:     db "The Winner is - Drone %d ",10,0
    format:      db "%d",10,0

section .data
    global SCHEDULER_CO 

    SCHEDULER_CO:     dd scheduler
                      dd SCH_ST+STKSZ
    active_drones: dd 0
    min_score:     dd 0

    
    extern CORS_ARR
    extern DRONES_ARR
    extern DRO_NUM
    extern K_STEPS
    extern PRINT_CO
    extern ROUND_ELIM
    extern printf
    extern loop1

        
section .bss
    SCH_ST:     resw STKSZ

section .text
    extern end
    align 16
    global scheduler
    extern resume
    extern printf
     
scheduler:
    mov     edx,0                ;edx - counter the steps until printing
    mov     edi,0                ;edi - counter number of rounds
.init_round:
    mov     ebx,[CORS_ARR]       ;ebx - holds the first co-routine of drone
    mov     ecx,0                ;ecx - counter of co-routine                  ;+1 number of rounds
    cmp     edi,[ROUND_ELIM]     
    jne     .new_round
    pushad
    call    elimination
    popad
    mov     edi,0
.new_round:
     inc     edi
    
.steps_round:
    cmp     ecx,[DRO_NUM]
    je      .init_round      ; starts again after scheduling all drones (round-robin)
    call    resume               ; resumes drone
    inc     ecx                  ; advances to the next drone
    inc     edx
    add     ebx,CO_SIZE          ; get the next co-routine
    cmp     edx,[K_STEPS]        ; checks if edx = K
    jne     .steps_round   
    mov     eax,ebx              ; save in eax the current co-routine
    mov     ebx,PRINT_CO         ; print the state of the game after K-steps by calling printer
    call    resume
    mov     edx,0                ; resets steps counter
    mov     ebx,eax
    jmp     .steps_round

;=============================================================================================

elimination:
    mov dword[min_score],0
    mov ecx,0
    mov ecx,[DRONES_ARR]    ;ecx hold ths first drone
    mov ebx,0               ;ebx count the drones

.init_min:
    cmp dword[ecx+ACTIVE],1      ;check if curr drone is activ
    je .first_active         ;if so, let min be first active drone score 
    add ecx, DRONE_SIZE     ;if we hasnt found the the first active drone,move to the next
    inc ebx                 ;inc the drone counter
    jmp .init_min      

.first_active:
    inc ebx                     ; inc drone counter
    mov edx,dword[ecx+SCORE]    ; let min be first active drone score
    mov dword[min_score],edx  
    mov ebx,0  

.find_min:                      ;find the real min score in thr arr
    cmp ebx,dword[DRO_NUM]            ;Checking whether we have gone through all drones
    je .found_min       
    cmp dword[ecx+ACTIVE],1          ;check if curr drone is active
    jne .next_drone 
    mov eax,0           
    mov eax,dword[min_score]   

    cmp eax,dword[ecx+SCORE]          ;check if the curr drone score is lower then mi
    jb .next_drone              
    mov eax,dword[ecx+SCORE]          ;replace min with the curr drone score
    mov dword[min_score],eax

.next_drone:
    inc ebx
    add ecx,DRONE_SIZE
    jmp .find_min

.found_min:                     ;now we have the min score, we need to find a drone with min score
    mov ecx,[DRONES_ARR]        ;ecx hold ths first drone
    mov ebx,0                   ;ebx count the drones
    mov eax,dword[min_score]

.find_drone_to_kill:

    cmp [ecx+SCORE],eax
    je .kill_drone
    add ecx,DRONE_SIZE
    jmp .find_drone_to_kill


.kill_drone:
    mov dword[ecx+ACTIVE],0

.end_of_game_check:
    mov ecx,[DRONES_ARR]        ;ecx hold ths first drone
    mov ebx,1                   ;ebx counter drones
    mov edi,0                   ;esi count activ drones
    mov eax,0                   ;eax hold the potential winner index

.loop_drones:
    cmp ebx,[DRO_NUM]            ;check if we are done looping
    jg .winner                  ;if so we have only 1 active drone and he s the winner
    cmp dword[ecx+ACTIVE],0          ;check if curr drone is active
    je .next                   ;if not,move to the next
    cmp edi,1                   ;check if curr drone is the second active drone
    je .not_end                 ;if so, the game didnt end
    inc edi                     ;if not inc active drone counter
    mov eax,ebx                 ;save potential winner index
    
.next:
    inc ebx                     ;inc counter
    add ecx,DRONE_SIZE          ;move to the next drone 
    jmp .loop_drones             

.not_end:
    ret

.winner:
    push    eax
    push    winner
    call    printf
    add     esp,8
    jmp end