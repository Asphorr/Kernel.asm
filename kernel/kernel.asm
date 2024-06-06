BITS 16
ORG 0x7C00

%define NULL 0

; Colors
%define WHITE_ON_BLACK 0x07
%define RED_ON_BLACK 0x04

; VGA Screen Parameters
%define VGA_WIDTH 80
%define VGA_HEIGHT 25
%define VGA_MEMORY 0xB8000

; Message Buffers
%define MSG_BUFFER_SIZE 1024
msg_buffer resb MSG_BUFFER_SIZE

; Tree-like Filesystem Structure
%define MAX_FILES 10
%define MAX_FILENAME_LEN 20
filesystem_start:
files db MAX_FILES
file_names times MAX_FILES dup (MAX_FILENAME_LEN + 1) db 0
file_contents times MAX_FILES dup (MSG_BUFFER_SIZE) db 0
file_sizes times MAX_FILES dw 0

boot_start:
    cli
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    ; Initialize the filesystem
    call init_filesystem

    ; Initialize GUI
    call init_gui
    call clear_screen

    ; Display welcome message
    call display_welcome

    ; Test filesystem
    call test_filesystem

    ; Main loop
hang:
    hlt
    jmp hang

; GUI Functions
init_gui:
    ; Initialize VGA Text Mode
    mov ax, 0x03
    int 0x10
    ret

clear_screen:
    ; Clear the screen with spaces
    mov di, VGA_MEMORY
    mov cx, VGA_WIDTH * VGA_HEIGHT
    mov al, ' '
    mov ah, WHITE_ON_BLACK
    rep stosw
    ret

print_string:
    ; Print string from DS:SI to the screen
    lodsb
    cmp al, 0
    je done_printing
    mov ah, WHITE_ON_BLACK
    mov di, VGA_MEMORY
    mov cx, VGA_WIDTH * VGA_HEIGHT
    repne scasw
    dec di
    stosw
    jmp print_string
done_printing:
    ret

display_welcome:
    mov si, welcome_msg
    call print_string
    ret

welcome_msg db "Welcome to BasicOS!", 0

; Filesystem Functions
init_filesystem:
    mov byte [files], 0
    ret

create_file:
    mov si, file_name
    mov di, file_names
    mov cx, MAX_FILES
    call find_empty_slot
    jc no_empty_slot

    ; Copy filename
    mov di, file_names
    rep movsb
    ret

    ; Initialize file content and size
    mov di, file_contents
    xor bx, bx
    mov cx, MSG_BUFFER_SIZE
    rep stosb
    mov di, file_sizes
    xor ax, ax
    stosw
    ret

no_empty_slot:
    ; Handle no available slots
    mov si, no_slot_msg
    call print_string
    ret

no_slot_msg db "Error: No empty file slots available!", 0

find_empty_slot:
    ; Find an empty slot in the file_names array
    mov di, file_names
    mov cx, MAX_FILES
find_empty_loop:
    lodsb
    cmp al, 0
    je empty_slot_found
    add di, MAX_FILENAME_LEN
    loop find_empty_loop
    stc
    ret
empty_slot_found:
    clc
    ret

write_file:
    ; Write content to the specified file
    mov si, file_name
    call find_file_index
    jc file_not_found

    ; Write content
    mov di, file_contents
    add di, bx
    mov si, file_content
    mov cx, MSG_BUFFER_SIZE
    rep movsb
    mov di, file_sizes
    add di, bx
    mov ax, MSG_BUFFER_SIZE
    stosw
    ret

file_not_found:
    ; Handle file not found
    mov si, not_found_msg
    call print_string
    ret

not_found_msg db "Error: File not found!", 0

find_file_index:
    ; Find the index of a filename in file_names
    mov di, file_names
    mov cx, MAX_FILES
find_file_loop:
    mov si, file_name
    repe cmpsb
    je file_found
    add di, MAX_FILENAME_LEN
    loop find_file_loop
    stc
    ret
file_found:
    lea bx, [di - file_names]
    div word [MAX_FILENAME_LEN]
    clc
    ret

read_file:
    ; Read content from the specified file
    mov si, file_name
    call find_file_index
    jc file_not_found

    ; Read content
    mov di, file_contents
    add di, bx
    mov si, msg_buffer
    mov cx, MSG_BUFFER_SIZE
    rep movsb
    ret

test_filesystem:
    ; Test the filesystem functions
    lea si, test_file_name
    lea di, file_name
    mov cx, MAX_FILENAME_LEN
    rep movsb
    lea si, test_file_content
    lea di, file_content
    mov cx, MSG_BUFFER_SIZE
    rep movsb
    call create_file
    call write_file

    ; Read back and print to the screen
    lea si, test_file_name
    lea di, file_name
    mov cx, MAX_FILENAME_LEN
    rep movsb
    call read_file
    lea si, msg_buffer
    call print_string
    ret

test_file_name db "test.txt", 0
test_file_content db "This is a test file in BasicOS.", 0

times 510-($-$$) db 0
dw 0xAA55
