; ----------------------------------------------------
; jeu de la vie - fits in your mbr, buy now !
;
; nasm -f bin gameoflife.asm
; qemu-system-i386 -hda gameoflife
;
; appuyer sur une touche lance une nouvelle génération
;
; - gruik / 2013
; ----------------------------------------------------
bits 16
org 0

%define LARGEUR   320   ; la largeur de l'écran
%define HAUTEUR   200   ; la hauteur de l'écran
%define COTE      190   ; la taille d'un coté du carré
%define VIDEO(x,y) ((y * LARGEUR) + x)

   jmp start

   ; ----------
   ; proc line - dessine une ligne verticale ou horizontale (selon AH) de CX pixels de long
line:
   mov al, 31        ; blanc
   mov cx, (COTE+1)
l1:
   mov [es:di], al
   cmp ah, 'v'       ; vertical or horizontal line ?
   je l2
   inc di            ; horizontal, on incremente simplement sur l'axe des x
   jmp l3
l2:
   add di, LARGEUR   ; vertical, on rajoute 1 ligne à DI
l3:
   loop l1
   ret

   ; -------------
   ; proc display - copie le tableau a l'ecran
display:
   mov si, 0
   mov di, VIDEO(((LARGEUR-COTE)/2),((HAUTEUR-COTE)/2))
   mov cx, COTE
l5:
   mov bx, cx
   mov cx, COTE
   rep movsb
   sub di, COTE
   add di, LARGEUR
   mov cx, bx
   loop l5
   ret

   ; ------------
   ; proc random - genere un nombre aleatoire dans ax
random:
   rdtsc
   xor al, ah
   xor ax, si
   xor ax, cx
   ret

   ; ---------------
   ; proc neibcount - compte les voisines de la cellule a l'ecran et remplit le tableau
neibcount:
   push cx
   xor ax, ax
   mov dx, [ds:((LARGEUR*HAUTEUR)+0)]		; DH = compteur de lignes (y) / DL = compteur de colonnes (x)
   mov cx, 7
l10:
   cmp cl, 2               ;  si cx < 3
   jg l11
   sub di, LARGEUR         ;     addr = addr - LARGEUR               |---|---|---|
   cmp dh, COTE            ;     si on est sur le bord haut          | 0 | 1 | 2 |
   jne l12                 ;        alors on wrap de l'autre coté:   |---|---|---|
   add di, (COTE*LARGEUR)  ;        addr = addr + (COTE*LARGEUR)     | 3 |   | 4 |
   jmp l12                 ;     jump l12                            |---|---|---|
l11:                       ;                                         | 5 | 6 | 7 |
   cmp cl, 5               ;  si cx > 4                              |---|---|---|
   jb l12
   add di, LARGEUR         ;     addr = addr + LARGEUR
   cmp dh, 1               ;     si on est sur le bord en bas
   jne l12                 ;        on wrap de l'autre coté:
   sub di, (COTE*LARGEUR)  ;        addr = addr - (COTE*LARGEUR)
l12:
   xor bx, bx
   inc bx
   shl bl, cl
   mov bh, bl              ;  on conserve le bl original dans bh pour reutilisation
   and bl, (1|8|32)
   test bl, bl             ;  si ((1<<cx) & (1|8|32)) != 0
   je l13
   dec di                  ;     addr = addr - 1                           |---|---|---|
   cmp dl, COTE            ;     si on est sur le bord gauche              | 1 | 2 | 4 |
   jne l14                 ;                                               |---|---|---|
   add di, COTE            ;        addr = addr + COTE                     | 8 |   | 16|
   jmp l14                 ;  jump l14                                     |---|---|---|
l13:                       ;                                               | 32| 64|128|
   mov bl, bh              ;  on recupere notre valeur de tout a l'heure   |---|---|---|
   and bl, (4|16|128)
   test bl, bl             ;  si ((1<<cx) & (4|16|128)) != 0
   je l14
   inc di                  ;     addr = addr + 1
   cmp dl, 1               ;  si on est sur le bord droit
   jne l14
   sub di, COTE            ;     addr = addr - COTE
l14:
   mov al, [es:di]         ;  on check la cellule voisine
   and al, 32
   test al, al             ;  est-ce qu'elle est vivante ?
   je l15
   inc ah                  ;     si oui on incremente le compteur (AH)
l15:
   mov di, [ds:((LARGEUR*HAUTEUR)+2)]   ; on retablit DI
   loop l10                ;  on boucle sur nos 8 cases
   mov al, [es:di]         ;  on recupere l'etat de notre cellule courrante
   cmp ah, 2               ;  2 voisines ?
   je l18
   cmp ah, 3               ;  3 voisines ?
   je l16
   jmp l17
l16:  ; 3 voisines vivantes
   mov al, 32              ;  la cellule nait ou reste vivante
   jmp l18
l17:  ; 0, 1 ou +3 voisines vivantes
   xor al, al              ;  la cellule meurt ou reste morte
   jmp l18
l18:  ; 2 voisines vivantes, la cellule reste comme elle est
   mov [ds:si], al
   pop cx
   ret

   ; -----------
   ; proc tempo - sert a temporiser, laisser passer quelques pouillèmes de seconde
tempo:
   xor ax, ax
   int 0x1a          ; int 1Ah, AH=0, on recup le tickcount dans CX:DX
   mov bx, dx
l9:
   xor ax, ax
   int 0x1a
   sub dx, bx
   cmp dx, 3         ; l'horloge bat 18.2x par seconde, donc une tempo d'environ ~110ms
   jb l9
   ret

start:
   mov ax, 0xa000    ; setup segments
   mov es, ax
   mov ax, 0x8000
   mov ds, ax
   mov ss, ax
   xor sp, sp

   mov ax, 0x0013    ; setup video mode 320x200x256
   int 0x10

   ; --------------------
   ; on dessine le cadre
   ;
   mov ah, 'h'       ; d'abord les lignes horizontales
   mov di, VIDEO((((LARGEUR-COTE)/2)-1),(((HAUTEUR-COTE)/2)-1))      ; ligne du haut, de gauche a droite
   call line
   mov di, VIDEO((((LARGEUR-COTE)/2)-1),(((HAUTEUR-COTE)/2)+COTE))   ; ligne du bas, de gauche a droite
   call line
   mov ah, 'v'       ; puis les lignes verticales
   mov di, VIDEO((((LARGEUR-COTE)/2)-1),(((HAUTEUR-COTE)/2)-1))      ; ligne de gauche, de haut en bas
   call line
   mov di, VIDEO((((LARGEUR-COTE)/2)+COTE),(((HAUTEUR-COTE)/2)-1))   ; ligne de droite, de haut en bas
   call line

   ; ----------------------------------------------------------------------------------------------
   ; on initialise le premier ecran en le remplissant aleatoirement de cellules vivantes ou mortes
   ;
   xor si, si
   mov cx, (COTE*COTE)
l4:
   push cx
   call random       ; recup un nombre aleatoire dans ax
   pop cx
   and al, 1         ; on garde uniquement le dernier bit
   shl al, 5         ; si la cellule est vivante couleur = 32 (un bleu vif), sinon couleur = 0
   mov [ds:si], al
   inc si
   loop l4
   call display      ; on affiche

   ; =====================
   ; | boucle principale |
   ; =====================
l6:
   xor si, si
   mov di, VIDEO(((LARGEUR-COTE)/2),((HAUTEUR-COTE)/2))
   xor cx, cx
   mov cl, COTE
l8:
   mov [ds:((LARGEUR*HAUTEUR)+0)], cl  ; for y=0; y<COTE {
   mov cl, COTE
l7:
   mov [ds:((LARGEUR*HAUTEUR)+1)], cl  ; for x=0; x<COTE {
   mov [ds:((LARGEUR*HAUTEUR)+2)], di  ; on garde DI au chaud pour utilisation dans neibcount
   call neibcount                      ; on compte les voisines
   inc si                              ; on incremente la source
   inc di                              ; et la destination
   mov cl, [ds:((LARGEUR*HAUTEUR)+1)]
   loop l7
   add di, LARGEUR-COTE                ; on remet DI a la ligne suivante sur le premier pixel
   mov cl, [ds:((LARGEUR*HAUTEUR)+0)]
   loop l8
   call display                        ; on affiche le tout
   call tempo                          ; on temporise pour pas que ca aille trop vite
   mov ax, 0x0100
   int 0x16                            ; si on presse une touche
   jz l6
   mov ah, 0
   int 0x16
   jmp start                           ; on relance une nouvelle generation

   times 446-($-$$) db 0
   times 64 db 0  ; y'a meme la place pour la table des partitions ;-P
   dw 0xaa55
