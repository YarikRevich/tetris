; Tetris
.286
.model small
.stack 100h
.data
    keyEsc equ 01h
    keyLeftArrow equ 4Bh
    keyRightArrow equ 4Dh

    leftBorderX equ 50
    rightBorderX equ 110
    bottomBorderY equ 25

    figureBorderY equ 24

    figure1 equ 1
    figure2 equ 2
    figureNone equ 3

    activeFigureShift equ 4
    activeFigureShiftHalf equ 2

    borderCollisionEnabled equ 1
    borderCollisionDisabled equ 2

    delayShift equ 1450
    gameOverEnabled equ 1

    gameOverShownEnabled equ 1

    updateMutexEnabled equ 1
    updateMutexDisabled equ 2

    scoreNumber equ 4

    delayGlobalSpeed equ 700

    keyList db 128 dup (0)

    updateMutex dw 0

    scoreFirst dw 0
    scoreSecond dw 0
    scoreThird dw 0
    scoreForth dw 0

    scoreCounter dw 0

    activeFigure dw 3

    activeX dw 80
    activeY dw 0

    tickerY dw 0

    borderCollisionRight dw 0
    borderCollisionLeft dw 0

    delayTickerSpeed dw 30000

    gameOverShown dw 0
    gameOver dw 0

    historyHead dw 1
    history db 800 dup (0)
    historyPtr dw 0
.code
main proc
    mov ax, 3509h
    int 21h
    push es
    push bx
    mov ax, seg onKey
    mov ds, ax
    mov dx, offset onKey
    mov ah, 25h
    mov al, 09h
    int 21h

    mov ax, @data
    mov ds, ax

    call enabledRendering
    call start

    call disableRendering

    pop dx
    pop ds

    mov ax, 2509h
    int 21h
    mov ax, 4C00h
    int 21h
main endp

proc enableRendering
    mov ax, 0B800h
    mov es, ax
    mov cx, 80*25
    ret
endp

proc disableRendering
    mov ah, 0
    mov al, 2
    int 10h
    ret
endp

proc start
    call drawBorders
    call selectActiveFigure

renderer:
    call delay
    call updateY

    call scanLeftMovement
    call scanRightMovement

    cmp activeFigure, figure1
    jne shift_active_figure1
    call drawFigure1

shift_active_figure1:
    cmp activeFigure, figure2
    jne shift_active_figure2
    call drawFigure2

shift_active_figure2:
    call drawScoreboard
    call drawMovements
    call drawGameover
    call scanBottomCollision

    cmp [cs:keyList + keyEsc], 1
    jne renderer

    ret
endp

proc drawBorders
    push es
    mov ah, 0F0h
    mov al, ' '
    mov di, leftBorderX
    mov cx, bottomBorderY

left:
    mov es:[di], ax
    add di, 80*2
    loop left    

    mov di, rightBorderX
    mov cx, bottomBorderY

right:
    mov es:[di], ax
    add di, 80*2
    loop right

    pop es
    ret
endp

proc addHistory
    push ax

    mov historyPtr, offset history

    inc historyHead
    mov cx, historyHead

add_history_loop:
    mov di, historyPtr
    add historyPtr, 2

    loop add_history_loop

    cmp activeFigure, figure1
    jne shift_add_figure1

    mov ax, activeY
    mov cx, 80*2
    mul cx
    add ax, activeX
    mov [di], ax
    jmp add_exit

shift_add_figure1:
    cmp activeFigure, figure2
    jne shift_add_figure2

    add historyPtr, 2
    mov ax, activeY
    mov cx, 80*2
    mul cx
    add ax, activeX
    mov [di], ax

    add ax, activeFigureShiftHalf

    add di, 2
    mov [di], ax

    jmp add_exit

shift_add_figure2:
add_exit:
    pop ax
    ret
endp

proc selectActiveFigure
    cmp activeFigure, figureNone
    jne shift_none

    mov activeFigure, figure1
    jmp figure_selection_exit

shift_none:
    cmp activeFigure, figure1
    jne shift_figure1

    mov activeFigure, figure2
    jmp figure_selection_exit

shift_figure1:
    cmp activeFigure, figure2
    jne shift_figure2

    mov activeFigure, figure1
    jmp figure_selection_exit

shift_figure2:
figure_selection_exit:
    ret
endp

proc onKey
    push ax
    push bx

    in al, 60h
    mov ah, 0
    mov bx, ax
    and bx, 127
    shl ax, 1
    xor ah, 1
    mov [keyList + bx], ah
    mov al, 20h
    out 20h, al

    pop bx
    pop ax

    iret
endp

proc scanRightMovement
    cmp gameOver, gameOverEnabled
    je scan_right_finish

    cmp [cs:keyList + keyrightArrow], 1
    jne scan_right_finish

    call scanRightBorderCollision

    cmp borderCollisionRight, borderCollisionEnabled
    je scan_right_finish

    mov borderCollisionRight, borderCollisionDisabled

    cmp activeFigure, figure1
    jne shift_right_movement_figure1
    call clearFigure1
    jmp right_movement_batch

shift_right_movement_figure1:
    cmp activeFigure, figure2
    jne shift_right_movement_figure2
    call clearFigure2
    jmp right_movement_batch

shift_right_movement_figure2:
right_movement_batch:
    add activeX, activeFigureShift

scan_right_finish:
    mov [cs:keyList + keyRightArrow], 0
    mov borderCollisionRight, borderCollisionDisabled
    ret
endp

proc scanLeftMovement
    cmp gameOver, gameOverEnabled
    je scan_left_finish

    cmp [cs:keyList + keyLeftArrow], 1
    jne scan_left_finish

    call scanLeftBorderCollision

    cmp borderCollisionLeft, borderCollisionEnabled
    je scan_left_finish

    mov borderCollisionLeft, borderCollisionDisabled

    cmp activeFigure, figure1
    jne shift_left_movement_figure1
    call clearFigure1
    jmp left_movement_batch

shift_left_movement_figure1:
    cmp activeFigure, figure2
    jne shift_left_movement_figure2
    call clearFigure2
    jmp left_movement_batch

shift_left_movement_figure2:
left_movement_batch:
    sub activeX, activeFigureShift

scan_left_finish:
    mov [cs:keyList + keyLeftArrow], 0
    mov borderCollisionLeft, borderCollisionDisabled
    ret
endp

proc scanBottomCollision
    push ax
    push bx

    mov historyPtr, offset history
    mov cx, historyHead

bottom_history_loop:
    mov di, historyPtr

    cmp activeFigure, figure1
    jne shift_bottom_collision_figure1

    mov ax, activeY
    add ax, 1
    mov bx, 80*2
    mul bx
    add ax, activeX
    mov bx, ax

    cmp [di], bx
    jne skip_bottom_history_loop
    je bottom_collision_check_batch

shift_bottom_collision_figure1:
    cmp activeFigure, figure2
    jne skip_bottom_history_loop

    mov ax, activeY
    add ax, 1
    mov bx, 80*2
    mul bx
    add ax, activeX
    mov bx, ax

    cmp [di], bx
    je bottom_collision_check_batch

    add bx, activeFigureShiftHalf

    cmp [di], bx
    jne skip_bottom_history_loop

bottom_collision_check_batch:
    cmp activeY, 0
    jne add_history

    mov gameOver, gameOverEnabled
    jmp skip_history_collision

skip_bottom_history_loop:
    add historyPtr, 2
    loop bottom_history_loop
    jmp skip_history_collision

add_history:
    call addHistory
    call increaseScore
    mov activeY, 0
    call updateX
    call selectActiveFigure

    sub delayTickerSpeed, delayShift

skip_history_collision:
    cmp activeY, figureBorderY
    jne skip_global_collision

    call addHistory
    call increaseScore
    mov activeY, 0
    call updateX
    call selectActiveFigure

    cmp delayTickerSpeed, delayShift
    jl skip_delay_speedup
    je skip_delay_speedup

    sub delayTickerSpeed, delayShift

skip_global_collision:
skip_delay_speedup:
    pop bx
    pop ax
    ret
endp

proc scanRightBorderCollision
    push ax
    push bx

    mov ax, rightBorderX
    sub ax, activeFigureShift
    sub ax, activeFigureShift

    cmp activeX, ax
    jl skip_right_border_collision

    mov borderCollisionRight, borderCollisionEnabled
    jmp right_collision_exit

skip_right_border_collision:
    mov historyPtr, offset history
    mov cx, historyHead

right_history_loop:
    mov di, historyPtr

    cmp activeFigure, figure1
    jne skip_right_history_figure_1

    mov ax, activeY
    mov bx, 80*2
    mul bx
    add ax, activeX
    add ax, activeFigureShift
    mov bx, ax

    cmp [di], bx
    jne skip_right_history_loop

    jmp right_history_batch

skip_right_history_figure_1:
    cmp activeFigure, figure2
    jne right_collision_exit

    mov ax, activeY
    mov bx, 80*2
    mul bx
    add ax, activeX
    add ax, activeFigureShiftHalf
    mov bx, ax

    cmp [di], bx
    je right_history_batch

    add bx, activeFigureShiftHalf
    cmp [di], bx
    jne skip_right_history_loop

    jmp right_history_batch

right_history_batch:
    mov borderCollisionRight, borderCollisionEnabled
    jmp right_collision_exit

skip_right_history_loop:
    add historyPtr, 2
    loop right_history_loop

right_collision_exit:
    pop bx
    pop ax
    ret
endp

proc scanLeftBorderCollision
    push ax
    push bx

    mov ax, leftBorderX
    add ax, activeFigureShift
    add ax, activeFigureShift

    cmp activeX, ax
    jg skip_left_border_collision

    mov borderCollisionLeft, borderCollisionEnabled
    jmp left_collision_exit

skip_left_border_collision:
    mov historyPtr, offset history
    mov cx, historyHead

left_history_loop:
    mov di, historyPtr

    cmp activeFigure, figure1
    jne skip_left_history_figure_1

    mov ax, activeY
    mov bx, 80*2
    mul bx
    add ax, activeX
    sub ax, activeFigureShift
    mov bx, ax

    cmp [di], bx
    jne skip_left_history_loop

    jmp left_history_batch

skip_left_history_figure_1:
    cmp activeFigure, figure2
    jne left_collision_exit

    mov ax, activeY
    mov bx, 80*2
    mul bx
    add ax, activeX
    sub ax, activeFigureShiftHalf
    mov bx, ax

    cmp [di], bx
    je left_history_batch

    sub bx, activeFigureShiftHalf
    cmp [di], bx
    jne skip_left_history_loop

    jmp left_history_batch

left_history_batch:
    mov borderCollisionLeft, borderCollisionEnabled
    jmp left_collision_exit

skip_left_history_loop:
    add historyPtr, 2
    loop left_history_loop

left_collision_exit:
    pop bx
    pop ax

    ret
endp

proc updateX
    push ax

    mov ax, leftBorderX
    add ax, rightBorderX

    mov bx, 2
    div bx

    cmp activeX, ax
    jne skip_update_x_equal

    push ax
    push bx

    add ax, rightBorderX
    mov bx, 2
    div bx
    add ax, 1
    mov activeX, ax

    pop bx
    pop ax
    jmp update_x_exit

skip_update_x_equal:
    cmp activeX, ax
    jg skip_update_x_lower

    push ax
    push bx

    mov ax, rightBorderX
    sub ax, activeFigureShift
    sub ax, activeX
    mov bx, 2
    div bx
    add activeX, ax

    test activeX, 1
    jz skip_update_x_lower_even

    inc activeX

skip_update_x_lower_even:
    pop bx
    pop ax

    jmp update_x_exit

skip_update_x_lower:
    cmp activeX, ax
    jl update_x_exit

    push ax
    push bx

    mov ax, activeX
    sub ax, leftBorderX
    sub ax, activeFigureShift
    mov bx, 2
    div bx
    sub activeX, ax

    test activeX, 1
    jz skip_update_x_greater_even

    inc activeX

skip_update_x_greater_even:
    pop bx
    pop ax

update_x_exit:
    pop ax
    ret
endp

proc updateY
    push ax

    cmp gameOver, gameOverEnabled
    je skip_update_y

    inc tickerY
    mov ax, delayTickerSpeed
    cmp tickerY, ax
    jne skip_update_y

    cmp activeFigure, figure1
    jne shift_update_y_figure1
    call clearFigure1
    jmp update_y_batch

shift_update_y_figure1:
    cmp activeFigure, figure2
    jne shift_update_y_figure2
    call clearFigure2
    jmp update_y_batch

shift_update_y_figure2:
update_y_batch:
    inc activeY
    mov tickerY, 0
skip_update_y:
    pop ax
    ret
endp

proc clearFigure1
    push es

    mov ah, 0h
    mov al, ''

    push ax
    mov ax, activeY
    mov cx, 80*2
    mul cx
    add ax, activeX
    mov di, ax
    pop ax

    mov es:[di], ax

    pop es
    ret
endp

proc drawFigure1
    push es

    mov ah, 0F0h
    mov al, ''

    push ax
    mov ax, activeY
    mov cx, 80*2
    mul cx
    add ax, activeX
    mov di, ax
    pop ax

    mov es:[di], ax

    pop es
    ret
endp

proc clearFigure2
    push es

    mov ah, 0h
    mov al, ''

    push ax
    mov ax, activeY
    mov cx, 80*2
    mul cx
    add ax, activeX
    mov di, ax
    pop ax

    mov es:[di], ax

    add di, activeFigureShiftHalf
    mov es:[di], ax

    pop es
    ret
endp

proc drawFigure2
    push es

    mov ah, 0F0h
    mov al, ''

    push ax
    mov ax, activeY
    mov cx, 80*2
    mul cx
    add ax, activeX
    mov di, ax
    pop ax

    mov es:[di], ax

    add di, activeFigureShiftHalf
    mov es:[di], ax

    pop es
    ret
endp

proc increaseScore
    cmp scoreFirst, 9
    je score_exceeded_first

    inc scoreFirst
    jmp score_increase_exit

score_exceeded_first:
    cmp scoreSecond, 9
    je score_exceeded_second

    mov scoreFirst, 0
    inc scoreSecond
    jmp score_increase_exit

score_exceeded_second:
    cmp scoreThird, 9
    je score_exceeded_third

    mov scoreFirst, 0
    mov scoreSecond, 0
    inc scoreThird
    jmp score_increase_exit

score_exceeded_third:
    cmp scoreForth, 9
    je score_increase_exit

    mov scoreFirst, 0
    mov scoreSecond, 0
    mov scoreThird, 0
    inc scoreForth

score_increase_exit:
    ret
endp

proc drawScoreboard
    push es
    push bx

    mov scoreCounter, 0
    mov di, 2
    mov cx, scoreNumber

scoreboard_loop:
    cmp scoreCounter, 0
    jne skip_score_counter_0

    mov bx, scoreForth
    jmp skip_score_counter

skip_score_counter_0:
    cmp scoreCounter, 1
    jne skip_score_counter_1

    mov bx, scoreThird
    jmp skip_score_counter

skip_score_counter_1:
    cmp scoreCounter, 2
    jne skip_score_counter_2

    mov bx, scoreSecond
    jmp skip_score_counter

skip_score_counter_2:
    cmp scoreCounter, 3
    jne skip_score_counter

    mov bx, scoreFirst

    jmp skip_transition

loop_transition:
    jmp scoreboard_loop

skip_transition:
skip_score_counter:
    mov ah, 09h
    cmp bx, 0
    jne first_1
    mov al, '0'
first_1:
    cmp bx, 1
    jne first_2
    mov al, '1'
first_2:
    cmp bx, 2
    jne first_3
    mov al, '2'
first_3:
    cmp bx, 3
    jne first_4
    mov al, '3'
first_4:
    cmp bx, 4
    jne first_5
    mov al, '4'
first_5:
    cmp bx, 5
    jne first_6
    mov al, '5'
first_6:
    cmp bx, 6
    jne first_7
    mov al, '6'
first_7:
    cmp bx, 7
    jne first_8
    mov al, '7'
first_8:
    cmp bx, 8
    jne first_9
    mov al, '8'
first_9:
    cmp bx, 9
    jne skip_first
    mov al, '9'

skip_first:
    mov es:[di], ax
    add di, 2
    inc scoreCounter
    loop loop_transition

    pop bx
    pop es
    ret
endp

proc drawMovements
    push es

    mov di, 12
    mov ah, 09h
    mov al, 'M'

    mov es:[di], ax

    mov al, 'o'
    add di, 2
    mov es:[di], ax

    mov al, 'v'
    add di, 2
    mov es:[di], ax

    mov al, 'e'
    add di, 2
    mov es:[di], ax

    mov al, 's'
    add di, 2
    mov es:[di], ax

    pop es
    ret
endp

proc drawGameover
    push es

    cmp gameOver, gameOverEnabled
    jne skip_game_over

    cmp gameOverShown, gameOverShownEnabled
    je skip_game_over_shown

    mov gameOverShown, gameOverShownEnabled

    push ax
    mov ax, 20
    mov cx, 80*2
    mul cx
    mov di, ax
    pop ax

    mov ah, 09h
    mov al, 'G'

    add di, 12
    mov es:[di], ax

    mov al, 'a'
    add di, 2
    mov es:[di], ax

    mov al, 'm'
    add di, 2
    mov es:[di], ax

    mov al, 'e'
    add di, 2
    mov es:[di], ax

    mov al, ' '
    add di, 2
    mov es:[di], ax

    mov al, 'o'
    add di, 2
    mov es:[di], ax

    mov al, 'v'
    add di, 2
    mov es:[di], ax

    mov al, 'e'
    add di, 2
    mov es:[di], ax

    mov al, 'r'
    add di, 2
    mov es:[di], ax

skip_game_over_shown:
skip_game_over:
    pop es
    ret
endp

proc delay
    mov cx, delayGlobalSpeed

await:
    loop await

    ret

endp
end main