;
; match.asm - line_matches, substring search with case folding and word
; boundaries. Callable from C.
;
; This is your starting point: it assembles and links as-is, so the build
; works before you write any code. Right now it always returns 0 (no
; match), which makes rengrep print nothing. Your job is to replace that
; with the search described below.
;
; The contract, from driver.c:
;
;       int line_matches(char *line, int linelen,
;                        char *pat, int patlen,
;                        int fold, int whole)
;
; so on the stack after a cdecl call:
;       [ebp+8]  = line
;       [ebp+12] = linelen
;       [ebp+16] = pat
;       [ebp+20] = patlen
;       [ebp+24] = fold
;       [ebp+28] = whole
;
; Return 1 in eax if pat occurs in line, 0 otherwise.
;
; Requirements from the manual:
;
;   * Use the x86 string instructions for the inner comparison. repe cmpsb
;     at minimum. A mov/cmp loop does not satisfy the activity.
;   * fold: compare case-insensitively WITHOUT modifying the buffer. Fold
;     in a register at comparison time. This path cannot use repe cmpsb
;     (it compares raw bytes), so a folding loop for that path is expected.
;   * whole: a match counts only when the byte before the match and the
;     byte after it are both non-word characters or absent. A failed
;     word-boundary check does NOT end the search. Keep scanning.
;   * The search bound is linelen - patlen, not linelen. Compare it with a
;     signed jump. When patlen is larger than linelen the difference is
;     negative. An unsigned jump reads it as enormous, and the scan runs
;     off the line into memory the process does not own and faults. This
;     is the Block 5 lesson.
;   * An empty pattern matches at every position, as it does in grep. A
;     rep prefix with ecx = 0 executes nothing and leaves the flags as they
;     were, so set ZF yourself before repe cmpsb. A bottom-tested folding
;     loop needs its own guard.
;   * Set cld explicitly. The direction flag persists across calls and
;     assuming it is clear is how a routine that works alone breaks when
;     called after something else.
;   * Preserve ebx, esi, edi, and ebp. Return in eax.
;   * No calls into the C standard library.
;
; Word characters are A-Z, a-z, 0-9, and _.
;

%ifdef ELF_TYPE
  %define _line_matches line_matches
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _line_matches

_line_matches:
        enter   0,0
        pusha

        ; Bounds check: max_start = linelen - patlen

        mov     eax, [ebp+12]       ; eax = linelen
        sub     eax, [ebp+20]       ; eax = linelen - patlen
        js      .no_match           ; If negative, pattern > line

        ; Empty pattern check
        ; mov     ecx, [ebp+20]       ; ecx = patlen
        ; test    ecx, ecx
        ; jz      .potential_match    ; Matches immediately

        ; Outer loop setup
        xor     ebx, ebx            ; ebx = start offset

.candidate_loop:
        cmp     ebx, eax
        jg      .no_match           ; Tried all valid offsets

        ; Set up pointers for comparison
        mov     esi, [ebp+16]       ; esi = pat
        mov     edi, [ebp+8]        ; edi = line
        add     edi, ebx            ; edi = line + start
        mov     ecx, [ebp+20]       ; ecx = patlen

        ; Check if folding is enabled
        cmp     dword [ebp+24], 0
        jne     .do_fold

        ; Fast path (no folding)
        cld                         ; set direction flag forward
        test    ecx, ecx            ; check for empty pattern
        jz      .potential_match
        repe cmpsb                  
        jne     .next_candidate
        jmp     .potential_match

.do_fold:
        ; Implement folding loop here
        ; Compare case-insensitively then;
        ; Jump to .potential_match on success,
        ; or .next_candidate on failure
        ; Preserve esi, edi, ecx logic for the loop

        test    ecx, ecx            ; empty pattern matches
        jz      .potential_match

.fold_loop:
        mov     dl, [esi]           ; pattern byte (copy)
        mov     dh, [edi]           ; line byte (copy)
        cmp     dl, 'A'
        jb      .pat_folded
        cmp     dl, 'Z'
        ja      .pat_folded
        add     dl, 32              ; to lowercase (register only)


.pat_folded:
        cmp     dh, 'A'
        jb      .line_folded
        cmp     dh, 'Z'
        ja      .line_folded
        add     dh, 32              ; to lowercase (register only)

.line_folded:
        cmp     dl, dh
        jne     .next_candidate
        inc     esi
        inc     edi
        dec     ecx
        jnz     .fold_loop          ; all matched: fall through

.potential_match:
        ; Check if word boundaries are enabled
        cmp     dword [ebp+28], 0               ; check if whole is enabled
        je      .match_found

        ; Implement word boundary check here
        ; ebx is the start offset
        ; Check byte at ebx-1 and ebx+patlen
        mov     esi, [ebp+8]        ; esi = line
        test    ebx, ebx            ; at line start?
        jz      .check_after
        mov     dl, [esi+ebx-1]     ; byte before
        call    is_word_char
        jc      .next_candidate

.check_after:
        mov     ecx, ebx
        add     ecx, [ebp+20]       ; ecx = start + patlen
        cmp     ecx, [ebp+12]       ; at line end?
        jge     .match_found
        mov     dl, [esi+ecx]       ; byte after
        call    is_word_char
        jc      .next_candidate
        jmp     .match_found

.next_candidate:
        inc     ebx
        jmp     .candidate_loop

.match_found:
        popa
        mov     eax, 1
        leave
        ret

.no_match:
        popa
        mov     eax, 0
        leave
        ret

; is_word_char: sets carry flag if dl is A-Z, a-z, 0-9 or _
is_word_char:
        cmp     dl, '_'
        je      .yes
        cmp     dl, '0'
        jb      .no
        cmp     dl, '9'
        jbe     .yes
        cmp     dl, 'A'
        jb      .no
        cmp     dl, 'Z'
        jbe     .yes
        cmp     dl, 'a'
        jb      .no
        cmp     dl, 'z'
        jbe     .yes
.no:    clc
        ret
.yes:   stc
        ret