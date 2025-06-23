#####################################################################
# Proyecto de Arquitecturas Gráficas - URJC
# Autores: - Claudia Porcuna Alexandra Pop
#
# Bitmap Display:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000 ($gp)
#
# Juego Arkanoid básico con ladrillos
# Mover la pala con teclas A (izquierda) y D (derecha)
#####################################################################
.data
COLOR_BG:      .word 0xADD8E6     # Fondo azul clarito
COLOR_PALA:    .word 0x006400     # Verde oscuro
COLOR_BOLA:    .word 0x404040     # Gris oscuro
COLOR_BRICK:   .word 0xFF0000     # Rojo ladrillo

BRICKS: .word 1,1,1,1,1,1,1,1,1,1
        .word 1,1,1,1,1,1,1,1,1,1
        .word 1,1,1,1,1,1,1,1,1,1
        .word 1,1,1,1,1,1,1,1,1,1
        .word 1,1,1,1,1,1,1,1,1,1

.text
.globl main

main:
    li $s0, 15         # Pala X
    li $s1, 29         # Pala Y
    li $s2, 20         # Bola X
    li $s3, 24         # Bola Y (inicial más arriba)
    li $s4, 1          # Dir X bola (1 derecha)
    li $s5, -1         # Dir Y bola (-1 arriba)
    li $s6, 32         # Ancho del display en celdas

main_loop:
    jal pintar_fondo
    jal pintar_ladrillos
    jal pintar_pala
    jal pintar_bola
    jal leer_tecla
    jal mover_pala
    jal mover_bola

    # Pausa para ver movimientos
    li $a0, 100
    li $v0, 32
    syscall

    j main_loop

# ----------- Pintar fondo
pintar_fondo:
    li $t0, 0x10008000
    li $t4, 1024          # 32x32
    lw $t2, COLOR_BG
loop_fondo:
    sw $t2, 0($t0)
    addiu $t0, $t0, 4
    addiu $t4, $t4, -1
    bgtz $t4, loop_fondo
    jr $ra

# ----------- Pintar pala
pintar_pala:
    lw $t0, COLOR_PALA
    li $t1, 5             # Ancho pala
    li $t2, 0x10008000
    mul $t3, $s1, $s6     # y * ancho
    add $t3, $t3, $s0     # + x
    sll $t3, $t3, 2
    add $t2, $t2, $t3
loop_pala:
    sw $t0, 0($t2)
    addiu $t2, $t2, 4
    addiu $t1, $t1, -1
    bgtz $t1, loop_pala
    jr $ra

# ----------- Pintar bola
pintar_bola:
    lw $t0, COLOR_BOLA
    li $t1, 0x10008000
    mul $t2, $s3, $s6
    add $t2, $t2, $s2
    sll $t2, $t2, 2
    add $t1, $t1, $t2
    sw $t0, 0($t1)
    jr $ra

# ----------- Pintar ladrillos (5 filas x 10 columnas)
pintar_ladrillos:
    li $t0, 0            # fila = 0
pintar_fila:
    li $t1, 0            # columna = 0
pintar_columna:
    la $t2, BRICKS
    mul $t3, $t0, 10
    add $t3, $t3, $t1
    sll $t3, $t3, 2
    add $t2, $t2, $t3
    lw $t4, 0($t2)
    beqz $t4, skip_brick

    # Calcular dirección en display
    li $t5, 0x10008000
    mul $t6, $t0, 32      # y * 32
    add $t6, $t6, $t1     # + x
    sll $t6, $t6, 2
    add $t5, $t5, $t6

    # Pintar ladrillo
    lw $t7, COLOR_BRICK
    sw $t7, 0($t5)

skip_brick:
    addi $t1, $t1, 1
    li $t8, 10
    blt $t1, $t8, pintar_columna
    addi $t0, $t0, 1
    li $t8, 5
    blt $t0, $t8, pintar_fila
    jr $ra

# ----------- Leer tecla (adaptado para MARS)
leer_tecla:
    li $v0, 12       # leer carácter sin esperar Enter
    syscall
    move $t9, $v0    # guardamos tecla

    # DEBUG: imprimir tecla (opcional)
    move $a0, $t9
    li $v0, 1
    syscall
    li $a0, 10
    li $v0, 11
    syscall

    jr $ra

# ----------- Mover pala con teclas 'a' (97) y 'd' (100)
mover_pala:
    li $t0, 97         # 'a'
    beq $t9, $t0, pala_izq
    li $t0, 100        # 'd'
    beq $t9, $t0, pala_der
    jr $ra

pala_izq:
    bgtz $s0, mover_ok
    jr $ra

pala_der:
    li $t1, 27
    blt $s0, $t1, mover_ok
    jr $ra

mover_ok:
    li $t0, 97
    beq $t9, $t0, mover_izq
    li $t0, 100
    beq $t9, $t0, mover_der
    jr $ra

mover_izq:
    addi $s0, $s0, -1
    jr $ra

mover_der:
    addi $s0, $s0, 1
    jr $ra

# ----------- Mover bola con rebotes y destrucción de ladrillos
mover_bola:
    # Nueva posición tentativa
    add $t0, $s2, $s4   # nueva_x = bola_x + dir_x
    add $t1, $s3, $s5   # nueva_y = bola_y + dir_y

    # Rebote en paredes horizontales
    blt $t0, 0, rebote_x_lad
    li $t2, 31
    bgt $t0, $t2, rebote_x_lad
    # Rebote en techo
    blt $t1, 0, rebote_y_lad

    # Colisión con ladrillos (solo primeras 5 filas)
    li $t3, 5
    blt $t1, $t3, check_ladrillo
    j seguir_pala

check_ladrillo:
    la $t4, BRICKS
    mul $t5, $t1, 10      # fila * 10
    add $t5, $t5, $t0     # + columna
    sll $t5, $t5, 2
    add $t4, $t4, $t5
    lw $t6, 0($t4)
    beqz $t6, seguir_pala

    # Ladrillo golpeado: destruir y rebotar bola
    sw $zero, 0($t4)
    neg $s5, $s5
    j aplicar_nueva_pos

seguir_pala:
    # Rebote con pala
    addi $t3, $s1, -1
    bne $t1, $t3, aplicar_nueva_pos
    blt $t0, $s0, aplicar_nueva_pos
    li $t4, 5
    add $t5, $s0, $t4
    bge $t0, $t5, aplicar_nueva_pos
    neg $s5, $s5

aplicar_nueva_pos:
    move $s2, $t0
    move $s3, $t1
    jr $ra

rebote_x_lad:
    neg $s4, $s4
    j aplicar_nueva_pos

rebote_y_lad:
    neg $s5, $s5
    j aplicar_nueva_pos
