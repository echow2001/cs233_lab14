### syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1
LINE_OFFSET = 16

### memory-mapped I/O addresses and constants

# movement info
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024
GET_OPPONENT_HINT       = 0xffff00ec

TIMER                   = 0xffff001c

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

PUZZLE_SIZE = 512
SOLUTION_SIZE = 64

# other player info
GET_WOOD                = 0xffff2000
GET_STONE               = 0xffff2004
GET_WOOL                = 0xffff2008
GET_WOODWALL            = 0xffff200c
GET_STONEWALL           = 0xffff2010
GET_BED                 = 0xffff2014
GET_CHEST               = 0xffff2018
GET_DOOR                = 0xffff201c

GET_HYDRATION           = 0xffff2044
GET_HEALTH              = 0xffff2048

GET_INVENTORY           = 0xffff2034
GET_SQUIRRELS               = 0xffff2038

GET_MAP                 = 0xffff2040

# interrupt masks and acknowledge addresses
BONK_INT_MASK           = 0x1000      ## Bonk
BONK_ACK                = 0xffff0060  ## Bonk

TIMER_INT_MASK          = 0x8000      ## Timer
TIMER_ACK               = 0xffff006c  ## Timer

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

RESPAWN_INT_MASK        = 0x2000      ## Respawn
RESPAWN_ACK             = 0xffff00f0  ## Respawn

NIGHT_INT_MASK          = 0x4000      ## Night
NIGHT_ACK               = 0xffff00e0  ## Night

# world interactions -- input format shown with each command
# X = x tile [0, 39]; Y = y tile [0, 39]; t = block or item type [0, 9]; n = number of items [-128, 127]
CRAFT                   = 0xffff2024    # 0xtttttttt
ATTACK                  = 0xffff2028    # 0x0000XXYY

PLACE_BLOCK             = 0xffff202c    # 0xttttXXYY
BREAK_BLOCK             = 0xffff2020    # 0x0000XXYY
USE_BLOCK               = 0xffff2030    # 0xnnttXXYY, if n is positive, take from chest. if n is negative, give to chest.

SUBMIT_BASE             = 0xffff203c    # stand inside your base when using this command

MMIO_STATUS             = 0xffff204c    # updated with a status code after any MMIO operation

# possible values for MMIO_STATUS
# use ./QtSpimbot -debug for more info!
ST_SUCCESS              = 0  # operation completed succesfully
ST_BEYOND_RANGE         = 1  # target tile too far from player
ST_OUT_OF_BOUNDS        = 2  # target tile outside map
ST_NO_RESOURCES         = 3  # no resources available for PLACE_BLOCK
ST_INVALID_TARGET_TYPE  = 4  # block at target position incompatible with operation
ST_TOO_FAST             = 5  # operation performed too quickly after the last one
ST_STILL_HAS_DURABILITY = 6  # block was damaged by BREAK_BLOCK, but is not yet broken. hit it again.

# block/item IDs
ID_WOOD                 = 0
ID_STONE                = 1
ID_WOOL                 = 2
ID_WOODWALL             = 3
ID_STONEWALL            = 4
ID_BED                  = 5
ID_CHEST                = 6
ID_DOOR                 = 7
ID_GROUND               = 8  # not an item
ID_WATER                = 9  # not an item

.data
# put your data things here
.align 2
puzzle_ready: .word 0
puzzle_solution: .space SOLUTION_SIZE
puzzle_data: .space PUZZLE_SIZE

### Puzzle

inventory:    .word 0:8
map:          .word 0:1600

.text
main:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, RESPAWN_INT_MASK          # enable respawn interrupt
    or      $t4, $t4, NIGHT_INT_MASK            # enable nightfall interrupt
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12
    #part 1 code
# request puzzle write the address of the start of puzzlewrapper struct addr to the PUZZLE_REQUEST MMIO address
    la $t2 puzzle_data
    sw $t2 REQUEST_PUZZLE
    wait0:
    lw $t1 puzzle_ready
    beq $t1 $0 wait0
    jal solve_puzzle
    sw $0, puzzle_ready

    li $t2, 90
    sw $t2, ANGLE
    li $t2, 1 
    sw $t2, ANGLE_CONTROL

    li $a2, 5
    li $a1, 0x16
    jal go_to_y

    li $t2, 0
    sw $t2, ANGLE
    li $t2, 1 
    sw $t2, ANGLE_CONTROL

    li $a2, 5
    li $a0, 25
    jal go_to_x

    # water at 3, 3
    li $t2 0x0303
    sw $t2 USE_BLOCK
    
    
    #j infinite


    li $a2, 5
    li $a0, 300
    jal go_to_x

    # stone at 37, 3
    li $t2 0x2503
    sw $t2 BREAK_BLOCK
    
    #j infinite

    li $a2, 5
    li $a1, 300
    jal go_to_y
    # sheeps at 36, 37
    li $t2 0x2425
    sw $t2 BREAK_BLOCK


    li $t2, 180
    sw $t2, ANGLE
    li $t2, 1 
    sw $t2, ANGLE_CONTROL
    li $a2, 5
    li $a0, 40
    jal go_to_x
    # tree at 36, 37
    li $t2 0x0524
    sw $t2 BREAK_BLOCK
    # break block by store column idx in the upper 8 bits, row index in the lower 8 bits
    # to the memory address BREAK_BLOCK.
    li $t2 0x07 
    sw $t2 CRAFT
infinite:
    j infinite
go_to: 
#a0 target x cordinate 
#a1 target y coordinate
#a2 velocitity
#only uses t0,t1 registers
    sw $a2, VELOCITY
    scan_go_to:
    lw $t0, BOT_X
    lw $t1, BOT_Y
    bne $t0 $a0 scan_go_to
    bne $t1 $a1 scan_go_to
    sw $0, VELOCITY
    jr $ra
go_to_x: 
    sw $a2, VELOCITY
    scan_go_to_x:
    lw $t0, BOT_X
    #lw $t1, BOT_Y
    bne $t0 $a0 scan_go_to_x
    #bne $t1 $a1 scan_go_to_x
    sw $0, VELOCITY
    jr $ra
go_to_y: 
    sw $a2, VELOCITY
    scan_go_to_y:
    #lw $t0, BOT_X
    lw $t1, BOT_Y
    #bne $t0 $a0 scan_go_to_y
    bne $t1 $a1 scan_go_to_y
    sw $0, VELOCITY
    jr $ra

######puzzle solve code given######
#Puzzle solving functions
.globl draw_line
draw_line:
        lw      $t0, 4($a2)     # t0 = width = canvas->width
        li      $t1, 1          # t1 = step_size = 1
        sub     $t2, $a1, $a0   # t2 = end_pos - start_pos
        blt     $t2, $t0, cont
        move    $t1, $t0        # step_size = width;
cont:
        move    $t3, $a0        # t3 = pos = start_pos
        add     $t4, $a1, $t1   # t4 = end_pos + step_size
        lw      $t5, 12($a2)    # t5 = &canvas->canvas
        lbu     $t6, 8($a2)     # t6 = canvas->pattern
for_loop_draw_line:
        beq     $t3, $t4, end_for_draw_line
        div     $t3, $t0        #
        mfhi    $t7             # t7 = pos % width
        mflo    $t8             # t8 = pos / width
        mul     $t9, $t8, 4     # t9 = pos/width*4
        add     $t9, $t9, $t5   # t9 = &canvas->canvas[pos / width]
        lw      $t9, 0($t9)     # t9 = canvas->canvas[pos / width]
        add     $t9, $t9, $t7
        sb      $t6, 0($t9)     # canvas->canvas[pos / width][pos % width] = canvas->pattern
        add     $t3, $t3, $t1   # pos += step_size
        j       for_loop_draw_line
end_for_draw_line:
        jr      $ra



.globl flood_fill
flood_fill:
        sub     $sp, $sp, 20
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        move    $s0, $a0                # $s0 = row
        move    $s1, $a1                # $s1 = col
        move    $s2, $a2                # $s2 = marker
        move    $s3, $a3                # $s3 = canvas
        blt     $s0, $0, ff_return      # row < 0
        blt     $s1, $0, ff_return      # col < 0
        lw      $t0, 0($s3)             # $t0 = canvas->height
        bge     $s0, $t0, ff_return     # row >= canvas->height
        lw      $t0, 4($s3)             # $t0 = canvas->width
        bge     $s1, $t0, ff_return     # col >= canvas->width

        lw      $t0, 12($s3)            # canvas->canvas
        mul     $t1, $s0, 4
        add     $t0, $t1, $t0           # $t0 = &canvas->canvas[row]
        lw      $t0, 0($t0)             # canvas->canvas[row]
        add     $t1, $s1, $t0           # $t1 = &canvas->canvas[row][col]
        lbu     $t0, 0($t1)             # $t0 = curr = canvas->canvas[row][col]
        lbu     $t2, 8($s3)             # $t2 = canvas->pattern
        beq     $t0, $t2, ff_return     # curr == canvas->pattern
        beq     $t0, $s2, ff_return     # curr == marker

        sb      $s2, 0($t1)             # canvas->canvas[row][col] = marker
        sub     $a0, $s0, 1             # $a0 = row - 1
        jal     flood_fill              # flood_fill(row - 1, col, marker, canvas);
        move    $a0, $s0
        add     $a1, $s1, 1
        move    $a2, $s2
        move    $a3, $s3
        jal     flood_fill              # flood_fill(row, col + 1, marker, canvas);
        add     $a0, $s0, 1
        move    $a1, $s1
        move    $a2, $s2
        move    $a3, $s3
        jal     flood_fill              # flood_fill(row + 1, col, marker, canvas);
        move    $a0, $s0
        sub     $a1, $s1, 1
        move    $a2, $s2
        move    $a3, $s3
        jal     flood_fill              # flood_fill(row, col - 1, marker, canvas);

ff_return:
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        add     $sp, $sp, 20
        jr      $ra


.globl count_disjoint_regions_step
count_disjoint_regions_step:
        sub     $sp, $sp, 36
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        sw      $s4, 20($sp)
        sw      $s5, 24($sp)
        sw      $s6, 28($sp)
        sw      $s7, 32($sp)

        move    $s0, $a0
        move    $s1, $a1

        li      $s2, 0                  # $s2 = region_count
        li      $s3, 0                  # $s3 = row
        lw      $s4, 0($s1)             # $s4 = canvas->height
        lw      $s6, 4($s1)             # $s6 = canvas->width
        lw      $s7, 8($s1)             # canvas->pattern

cdrs_outer_for_loop:
        bge     $s3, $s4, cdrs_outer_end
        li      $s5, 0                  # $s5 = col

cdrs_inner_for_loop:
        bge     $s5, $s6, cdrs_inner_end
        lw      $t0, 12($s1)            # canvas->canvas
        mul     $t5, $s3, 4             # row * 4
        add     $t5, $t0, $t5           # &canvas->canvas[row]
        lw      $t0, 0($t5)             # canvas->canvas[row] 
        add     $t0, $t0, $s5           # &canvas->canvas[row][col]
        lbu     $t0, 0($t0)             # $t0 = canvas->canvas[row][col]
        beq     $t0, $s7, cdrs_skip_if  # curr_char != canvas->pattern
        beq     $t0, $s0, cdrs_skip_if  # curr_char != canvas->marker
        add     $s2, $s2, 1             # region_count++
        move    $a0, $s3
        move    $a1, $s5
        move    $a2, $s0
        move    $a3, $s1
        jal     flood_fill

cdrs_skip_if:
        add     $s5, $s5, 1             # col++
        j       cdrs_inner_for_loop

cdrs_inner_end:
        add     $s3, $s3, 1             # row++
        j       cdrs_outer_for_loop

cdrs_outer_end:
        move    $v0, $s2
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        lw      $s4, 20($sp)
        lw      $s5, 24($sp)
        lw      $s6, 28($sp)
        lw      $s7, 32($sp)
        add     $sp, $sp, 36
        jr      $ra



.globl count_disjoint_regions
count_disjoint_regions:
        sub     $sp, $sp, 36
        sw      $ra, 0($sp)
        sw      $s0, 4($sp)
        sw      $s1, 8($sp)
        sw      $s2, 12($sp)
        sw      $s3, 16($sp)
        sw      $s4, 20($sp)
        sw      $s5, 24($sp)
        sw      $s6, 28($sp)
        sw      $s7, 32($sp)
        move    $s0, $a0        # s0 = lines
        move    $s1, $a1        # s1 = canvas
        move    $s2, $a2        # s2 = solution

        lw      $s4, 0($s0)     # s4 = lines->num_lines
        li      $s5, 0          # s5 = i
        lw      $s6, 4($s0)     # s6 = lines->coords[0]
        lw      $s7, 8($s0)     # s7 = lines->coords[1]
for_loop_disjoint_regions:
        bgeu    $s5, $s4, end_for_disjoint_regions
        mul     $t2, $s5, 4     # t2 = i*4
        add     $t3, $s6, $t2   # t3 = &lines->coords[0][i]
        lw      $a0, 0($t3)     # a0 = start_pos = lines->coords[0][i]
        add     $t4, $s7, $t2   # t4 = &lines->coords[1][i]
        lw      $a1, 0($t4)     # a1 = end_pos = lines->coords[1][i]
        move    $a2, $s1
        jal     draw_line
        li      $t9, 2
        div     $s5, $t9
        mfhi    $t6             # t6 = i % 2
        addi    $a0, $t6, 65    # a0 = 'A' + (i % 2)
        move    $a1, $s1        # count_disjoint_regions_step('A' + (i % 2), canvas)
        jal     count_disjoint_regions_step   # v0 = count
        lw      $t6, 4($s2)     # t6 = solution->counts
        mul     $t7, $s5, 4
        add     $t7, $t7, $t6   # t7 = &solution->counts[i]
        sw      $v0, 0($t7)     # solution->counts[i] = count
        addi    $s5, $s5, 1     # i++
        j       for_loop_disjoint_regions

end_for_disjoint_regions:
        lw      $ra, 0($sp)
        lw      $s0, 4($sp)
        lw      $s1, 8($sp)
        lw      $s2, 12($sp)
        lw      $s3, 16($sp)
        lw      $s4, 20($sp)
        lw      $s5, 24($sp)
        lw      $s6, 28($sp)
        lw      $s7, 32($sp)
        add     $sp, $sp, 36
        jr      $ra

solve_puzzle:
  sub $sp, $sp, 32
  sw $ra, 0($sp)
  sw $s0, 4($sp)
  sw $s1, 8($sp)
  sw $s2, 12($sp)

  la $s0, puzzle_solution
  add $t2, $s0, 8
  sw $t2, 4($s0)
  la $s1, puzzle_data
  lw $t0, LINE_OFFSET($s1) #Grab the num of lines
  sw $t0, 0($s0) #Store in solution struct

  add $a0, $s1, LINE_OFFSET
  move $a1, $s1
  move $a2, $s0
  jal count_disjoint_regions
 
  add $s0, $s0, 8 #point to the array of solution
  sw $s0, SUBMIT_SOLUTION #submit the puzzle


  lw $ra, 0($sp)
  lw $s0, 4($sp)
  lw $s1, 8($sp)
  lw $s2, 12($sp)
  add $sp, $sp, 32

  jr $ra
######puzzle solve code given######

.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt


interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    and     $a0, $k0, RESPAWN_INT_MASK
    bne     $a0, 0, respawn_interrupt

    and     $a0, $k0, NIGHT_INT_MASK
    bne     $a0, 0, night_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    #Fill in your bonk handler code here
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill in your timer handler code here
    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
#    sub $sp, $sp, 4
#   sw  $ra, 0($sp)
#    jal solve_puzzle
#    lw $ra, 0($sp)
#    add $sp, $sp, 4
    li      $v0, 1
    sw      $v0, puzzle_ready

    #Fill in your puzzle interrupt code here
    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK
    li      $v0, 1
    sw      $v0, puzzle_ready
    #Fill in your respawn handler code here
    j       interrupt_dispatch

    night_interrupt:
    sw      $0, NIGHT_ACK
    #Fill in your nightfall handler code here
    j  interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret

