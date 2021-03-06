//
//  SFMBoardView.m
//  Stockfish
//
//  Created by Daylen Yang on 1/10/14.
//  Copyright (c) 2014 Daylen Yang. All rights reserved.
//

#import "SFMBoardView.h"
#import "Constants.h"
#import "SFMPieceView.h"
#import "SFMArrowView.h"

#include "../Chess/square.h"

@interface SFMBoardView()

@property NSColor *feltBackground;
@property NSColor *boardColor;
@property NSColor *lightSquareColor;
@property NSColor *darkSquareColor;
@property NSColor *fontColor;
@property NSColor *highlightColor;
@property NSShadow *boardShadow;
@property NSMutableArray *pieces;
@property NSMutableArray *arrows;

@end

@implementation SFMBoardView

#pragma mark - Instance Variables
Square highlightedSquares[32];
int numHighlightedSquares;

Square fromSquare;
Square toSquare;
BOOL hasDragged;

CGFloat leftInset;
CGFloat topInset;
CGFloat squareSideLength;

#pragma mark - Setters

- (void)updatePieceViews // and the arrow views too!
{
    numHighlightedSquares = 0;
    
    assert(self.position->is_ok());
    
    // Invalidate pieces array
    self.pieces = [NSMutableArray new];
    // Remove subviews
    [self setSubviews:[NSArray new]];
    
    for (Square sq = SQ_A1; sq <= SQ_H8; sq++) {
        Piece piece = self.position->piece_on(sq);
        if (piece != EMPTY) {
            SFMPieceView *pieceView = [[SFMPieceView alloc] initWithPieceType:piece onSquare:sq];
            [self addSubview:pieceView];
            [self.pieces addObject:pieceView];
        }
    }
    
    // Now for the arrows
    [self updateArrowViews];
    
    [self setNeedsDisplay:YES];
}

- (void)updateArrowViews
{
    for (NSView *view in self.subviews) {
        if ([view isKindOfClass:[SFMArrowView class]]) {
            [view removeFromSuperview];
        }
    }
    for (SFMArrowView *arrowView in self.arrows) {
        [self addSubview:arrowView];
        
        arrowView.fromPoint = [self coordinatesForSquare:arrowView.fromSquare leftOffset:leftInset + squareSideLength / 2 topOffset:topInset + squareSideLength / 2 sideLength:squareSideLength];
        arrowView.toPoint = [self coordinatesForSquare:arrowView.toSquare leftOffset:leftInset + squareSideLength / 2 topOffset:topInset + squareSideLength / 2 sideLength:squareSideLength];
        arrowView.squareSideLength = squareSideLength;
        
        [arrowView setFrame:self.bounds];
        [arrowView setNeedsDisplay:YES];
    }
}

- (void)setBoardIsFlipped:(BOOL)boardIsFlipped
{
    _boardIsFlipped = boardIsFlipped;
    for (SFMPieceView *pv in self.pieces) {
        [pv moveTo:[self coordinatesForSquare:pv.square leftOffset:leftInset topOffset:topInset sideLength:squareSideLength]];
    }
    [self updateArrowViews];
    
    [self setNeedsDisplay:YES];
}

#pragma mark - Init
- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setWantsLayer:YES];
        
        self.boardIsFlipped = NO;
        
        self.feltBackground = [NSColor colorWithPatternImage:[NSImage imageNamed:@"Felt"]];
        
        self.boardColor = [NSColor blackColor];
        self.lightSquareColor = [NSColor whiteColor];
        self.darkSquareColor = [NSColor brownColor];
        self.fontColor = [NSColor whiteColor];
        self.highlightColor = [NSColor colorWithSRGBRed:1 green:1 blue:0 alpha:0.7];
        
        self.boardShadow = [NSShadow new];
        [self.boardShadow setShadowBlurRadius:BOARD_SHADOW_BLUR_RADIUS];
        [self.boardShadow setShadowColor:[NSColor colorWithGenericGamma22White:0 alpha:0.75]]; // Gray
        
        self.position = new Position([FEN_START_POSITION UTF8String]);
        
        self.arrows = [NSMutableArray new];
        
    }
    return self;
}

#pragma mark - Draw
- (void)drawRect:(NSRect)dirtyRect
{
    // Draw a felt background
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    [self.feltBackground set];
    NSRectFill([self bounds]);
    [context restoreGraphicsState];
    
    // Draw the big square
    CGFloat height = self.bounds.size.height;
    CGFloat width = self.bounds.size.width;
    CGFloat boardSideLength = MIN(height, width) - EXTERIOR_BOARD_MARGIN * 2;
    
    [self.boardColor set];
    [self.boardShadow set];
    
    CGFloat left = (width - boardSideLength) / 2;
    CGFloat top = (height - boardSideLength) / 2;
    
    NSRectFill(NSMakeRect(left, top, boardSideLength, boardSideLength));
    [[NSShadow new] set];
    
    leftInset = left + INTERIOR_BOARD_MARGIN;
    topInset = top + INTERIOR_BOARD_MARGIN;
    squareSideLength = (boardSideLength - 2 * INTERIOR_BOARD_MARGIN) / 8;
    
    // Draw 64 squares
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            if ((i + j) % 2 == 0) {
                [self.lightSquareColor set];
            } else {
                [self.darkSquareColor set];
            }
            NSRectFill(NSMakeRect(leftInset + i * squareSideLength, topInset + j * squareSideLength, squareSideLength, squareSideLength));
        }
    }
    
    // Draw coordinates
    NSString *str = [NSString new];
    NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    [pStyle setAlignment:NSCenterTextAlignment];
    
    for (int i = 0; i < 8; i++) {
        // Down
        str = [NSString stringWithFormat:@"%d", self.boardIsFlipped ? (i + 1) : (8 - i)];
        [str drawInRect:NSMakeRect(left, topInset + squareSideLength / 2 - FONT_SIZE / 2 + i * squareSideLength, INTERIOR_BOARD_MARGIN, squareSideLength) withAttributes:@{NSParagraphStyleAttributeName: pStyle, NSForegroundColorAttributeName: self.fontColor}];
        // Across
        str = [NSString stringWithFormat:@"%c", self.boardIsFlipped ? ('h' - i) : ('a' + i)];
        [str drawInRect:NSMakeRect(leftInset + i * squareSideLength, topInset + 8 * squareSideLength, squareSideLength, INTERIOR_BOARD_MARGIN) withAttributes:@{NSParagraphStyleAttributeName: pStyle, NSForegroundColorAttributeName: self.fontColor}];
    }
    
    // Draw pieces
    for (SFMPieceView *pieceView in self.pieces) {
        CGPoint coordinate = [self coordinatesForSquare:pieceView.square leftOffset:leftInset topOffset:topInset sideLength:squareSideLength];
        [pieceView setFrame:NSMakeRect(coordinate.x, coordinate.y, squareSideLength, squareSideLength)];
        [pieceView setNeedsDisplay:YES];
        
    }
    
    // Draw highlights
    [self.highlightColor set]; // Highlight color

    for (int i = 0; i < numHighlightedSquares; i++) {
        CGPoint coordinate = [self coordinatesForSquare:highlightedSquares[i] leftOffset:leftInset topOffset:topInset sideLength:squareSideLength];
        [NSBezierPath fillRect:NSMakeRect(coordinate.x, coordinate.y, squareSideLength, squareSideLength)];
    }
    
    // Draw arrows
    for (SFMArrowView *arrowView in self.arrows) {
        
        arrowView.fromPoint = [self coordinatesForSquare:arrowView.fromSquare leftOffset:leftInset + squareSideLength / 2 topOffset:topInset + squareSideLength / 2 sideLength:squareSideLength];
        arrowView.toPoint = [self coordinatesForSquare:arrowView.toSquare leftOffset:leftInset + squareSideLength / 2 topOffset:topInset + squareSideLength / 2 sideLength:squareSideLength];
        arrowView.squareSideLength = squareSideLength;

        [arrowView setFrame:self.bounds];
        [arrowView setNeedsDisplay:YES];
    }
}

#pragma mark - Arrows

- (void)clearArrows
{
    [self.arrows removeAllObjects];
    [self updateArrowViews];
}
- (void)addArrowFrom:(Square)from to:(Square)to
{
    SFMArrowView *arrowView = [[SFMArrowView alloc] init];
    arrowView.fromSquare = from;
    arrowView.toSquare = to;
    [self.arrows addObject:arrowView];
    [self updateArrowViews];
}

#pragma mark - Helper methods

- (CGPoint)coordinatesForSquare:(Square)sq
                     leftOffset:(CGFloat)left
                      topOffset:(CGFloat)top
                     sideLength:(CGFloat)sideLength
{
    int letter = sq % 8;
    int number = sq / 8;
    CGFloat l, t;
    if (self.boardIsFlipped) {
        l = left + (7 - letter) * sideLength;
        t = top + number * sideLength;
    } else {
        l = left + letter * sideLength;
        t = top + (7 - number) * sideLength;
    }
    return CGPointMake(l, t);
}
- (Square)squareForCoordinates:(NSPoint)point
                    leftOffset:(CGFloat)left
                     topOffset:(CGFloat)top
                    sideLength:(CGFloat)sideLength
{
    int letter, number;
    if (self.boardIsFlipped) {
        letter = (int) (point.x - left) / (int) sideLength;
        letter = 7 - letter;
        number = (int) (point.y - top) / (int) sideLength;
    } else {
        letter = (int) (point.x - left) / (int) sideLength;
        number = (int) (point.y - top) / (int) sideLength;
        number = 7 - number;
    }
    if (!(letter >= 0 && letter <= 7 && number >= 0 && number <= 7)) {
        return SQ_NONE;
    }
    return static_cast<Square>(8 * number + letter);
}

#pragma mark - Interaction

- (void)mouseDown:(NSEvent *)theEvent
{
    hasDragged = NO;
    
    // Figure out which square you clicked on
    NSPoint clickLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    Square clickedSquare = [self squareForCoordinates:clickLocation leftOffset:leftInset topOffset:topInset sideLength:squareSideLength];
    
    if (numHighlightedSquares == 0) {
        // You haven't selected a valid piece, since there are no highlighted
        // squares on the board.
        if (clickedSquare != SQ_NONE) {
            [self displayPossibleMoveHighlightsForPieceOnSquare:clickedSquare];
            fromSquare = clickedSquare;
            
            // Bring to front
            SFMPieceView *view = [self pieceViewOnSquare:fromSquare];
            CALayer* superlayer = [[view layer] superlayer];
            [[view layer] removeFromSuperlayer];
            [superlayer addSublayer:[view layer]];
            
            // But the arrow needs to be even more above
            [self updateArrowViews];
        }
        
    } else {
        // Is it possible to move to the square you clicked on?
        BOOL isValidMove = NO;
        for (int i = 0; i < numHighlightedSquares; i++) {
            if (highlightedSquares[i] == clickedSquare) {
                isValidMove = YES;
                break;
            }
        }
        
        if (!isValidMove) {
            // If it's not a valid move, cancel the highlight
            numHighlightedSquares = 0;
            fromSquare = SQ_NONE;
        }
    }
    
    [self setNeedsDisplay:YES];
    
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    hasDragged = YES;
    
    // Make the dragged piece follow the mouse
    NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    // Center the piece
    mouseLocation.x -= squareSideLength / 2;
    mouseLocation.y -= squareSideLength / 2;
    
    SFMPieceView *draggedPiece = [self pieceViewOnSquare:fromSquare];
    [draggedPiece setFrameOrigin:mouseLocation];
    [draggedPiece setNeedsDisplay:YES];
    
}

- (void)mouseUp:(NSEvent *)theEvent
{
    // Figure out which square you let go on
    NSPoint upLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    toSquare = [self squareForCoordinates:upLocation leftOffset:leftInset topOffset:topInset sideLength:squareSideLength];
    
    // Is it possible to move to the square you clicked on?
    BOOL isValidMove = NO;
    for (int i = 0; i < numHighlightedSquares; i++) {
        if (highlightedSquares[i] == toSquare) {
            isValidMove = YES;
            break;
        }
    }
    
    if (numHighlightedSquares != 0 && toSquare != SQ_NONE && isValidMove) {
        // You previously selected a valid piece, and now you're trying to move it
        
        PieceType pieceType = NO_PIECE_TYPE;
        
        // Handle promotions
        if ([self isPromotionForMoveFromSquare:fromSquare to:toSquare]) {
            pieceType = [self getDesiredPromotionPiece];
        }
        
        // HACK: Castling. The user probably tries to move the king two squares to
        // the side when castling, but Stockfish internally encodes castling moves
        // as "king captures rook". We handle this by adjusting tSq when the user
        // tries to move the king two squares to the side:
        BOOL castle = NO;
        
        if (fromSquare == SQ_E1 && toSquare == SQ_G1 &&
            self.position->piece_on(fromSquare) == WK) {
            toSquare = SQ_H1;
            castle = YES;
        } else if (fromSquare == SQ_E1 && toSquare == SQ_C1 &&
                   self.position->piece_on(fromSquare) == WK) {
            toSquare = SQ_A1;
            castle = YES;
        } else if (fromSquare == SQ_E8 && toSquare == SQ_G8 &&
                   self.position->piece_on(fromSquare) == BK) {
            toSquare = SQ_H8;
            castle = YES;
        } else if (fromSquare == SQ_E8 && toSquare == SQ_C8 &&
                   self.position->piece_on(fromSquare) == BK) {
            toSquare = SQ_A8;
            castle = YES;
        }

        [self clearArrows];
        Move theMove = [self.delegate doMoveFrom:fromSquare to:toSquare promotion:pieceType];
        UndoInfo u;
        [self animatePieceOnSquare:fromSquare to:toSquare promotion:pieceType shouldCastle:castle];
        self.position->do_move(theMove, u);
        numHighlightedSquares = 0;
        
    } else {
        
        // Not a valid move, slide it back
        SFMPieceView *piece = [self pieceViewOnSquare:fromSquare];
        [piece moveTo:[self coordinatesForSquare:piece.square leftOffset:leftInset topOffset:topInset sideLength:squareSideLength]];
    }
    
    if (hasDragged) {
        numHighlightedSquares = 0;
    }
    
    [self setNeedsDisplay:YES];
    
}

- (SFMPieceView *)pieceViewOnSquare:(Square)square
{
    for (SFMPieceView *pieceView in self.pieces) {
        if (pieceView.square == square) {
            return pieceView;
        }
    }
    return nil;
}

// Sets the piece view's square property and executes an animated move
- (void)movePieceView:(SFMPieceView *)pieceView toSquare:(Square)square
{
    pieceView.square = square;
    [pieceView moveTo:[self coordinatesForSquare:square leftOffset:leftInset topOffset:topInset sideLength:squareSideLength]];
}

- (void)animatePieceOnSquare:(Square)fromSquare
                          to:(Square)toSquare
                   promotion:(PieceType)desiredPromotionPiece
                shouldCastle:(BOOL)shouldCastle
{
    
    // Find the piece(s)
    SFMPieceView *thePiece = [self pieceViewOnSquare:fromSquare];
    SFMPieceView *capturedPiece = [self pieceViewOnSquare:toSquare];
    
    if (shouldCastle) {
        // Castle
        if (toSquare == SQ_H1) {
            // White kingside
            [self movePieceView:[self pieceViewOnSquare:SQ_H1] toSquare:SQ_F1]; // Rook
            [self movePieceView:thePiece toSquare:SQ_G1]; // King
            
        } else if (toSquare == SQ_A1) {
            // White queenside
            [self movePieceView:[self pieceViewOnSquare:SQ_A1] toSquare:SQ_D1]; // Rook
            [self movePieceView:thePiece toSquare:SQ_C1]; // King
            
        } else if (toSquare == SQ_H8) {
            // Black kingside
            [self movePieceView:[self pieceViewOnSquare:SQ_H8] toSquare:SQ_F8]; // Rook
            [self movePieceView:thePiece toSquare:SQ_G8]; // King
            
        } else {
            // Black queenside
            [self movePieceView:[self pieceViewOnSquare:SQ_A8] toSquare:SQ_D8]; // Rook
            [self movePieceView:thePiece toSquare:SQ_C8]; // King
            
        }
    } else if (desiredPromotionPiece != NO_PIECE_TYPE) {
        // Promotion
        
        // Remove all relevant pieces
        [thePiece removeFromSuperview];
        [self.pieces removeObject:thePiece];
        
        if (capturedPiece) {
            // You could capture while promoting
            [capturedPiece removeFromSuperview];
            [self.pieces removeObject:capturedPiece];
        }
        
        // Create a new piece view and add it
        SFMPieceView *pieceView = [[SFMPieceView alloc] initWithPieceType:piece_of_color_and_type(self.position->side_to_move(), desiredPromotionPiece) onSquare:toSquare];
        [self addSubview:pieceView];
        [self.pieces addObject:pieceView];
    } else if (capturedPiece) {
        // Capture
        
        // Remove the captured piece
        [capturedPiece removeFromSuperview];
        [self.pieces removeObject:capturedPiece];
        
        // Do a normal move
        [self movePieceView:thePiece toSquare:toSquare];
    } else if (type_of_piece(self.position->piece_on(fromSquare)) == PAWN &&
               square_file(fromSquare) != square_file(toSquare)) {
        // En passant
        
        // Find the en passant square
        Square enPassantSquare = toSquare - pawn_push(self.position->side_to_move());
        
        // Remove the piece on that square
        SFMPieceView *toRemove = [self pieceViewOnSquare:enPassantSquare];
        [toRemove removeFromSuperview];
        [self.pieces removeObject:toRemove];
        
        // Do a normal move
        [self movePieceView:thePiece toSquare:toSquare];
    } else {
        // Normal move
        [self movePieceView:thePiece toSquare:toSquare];
    }
    
}




- (void)displayPossibleMoveHighlightsForPieceOnSquare:(Chess::Square)sq
{
    fromSquare = sq;
    numHighlightedSquares = [self destinationSquaresFrom:sq saveInArray:highlightedSquares];
    [self setNeedsDisplay:YES];
}

#pragma mark - Promotion

- (BOOL)isPromotionForMoveFromSquare:(Square)fromSquare to:(Square)toSquare
{
    Move mlist[32];
    int i, n, count;
    
    assert(square_is_ok(fromSquare));
    assert(square_is_ok(toSquare));
    n = self.position->moves_from(fromSquare, mlist);
    for (i = 0, count = 0; i < n; i++)
        if (move_to(mlist[i]) == toSquare)
            count++;
    return count > 1;
}

- (PieceType)getDesiredPromotionPiece
{    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Queen"];
    [alert addButtonWithTitle:@"Rook"];
    [alert addButtonWithTitle:@"Bishop"];
    [alert addButtonWithTitle:@"Knight"];
    [alert setMessageText:@"Pawn Promotion"];
    [alert setInformativeText:@"What would you like to promote your pawn to?"];
    [alert setAlertStyle:NSWarningAlertStyle];
    NSInteger choice = [alert runModal];
    switch (choice) {
        case 1000:
            return QUEEN;
        case 1001:
            return ROOK;
        case 1002:
            return BISHOP;
        case 1003:
            return KNIGHT;
        default:
            return NO_PIECE_TYPE;
    }
}

#pragma mark - Logic
/// destinationSquaresFrom:saveInArray takes a square and a C array of squares
/// as input, finds all squares the piece on the given square can move to,
/// and stores these possible destination squares in the array. This is used
/// in the GUI in order to highlight the squares a piece can move to.

- (int)destinationSquaresFrom:(Square)sq saveInArray:(Square *)sqs {
    int i, j, n;
    Move mlist[32];
    
    assert(square_is_ok(sq));
    assert(sqs != NULL);
    
    
    n = [self movesFrom: sq saveInArray: mlist];
    for (i = 0, j = 0; i < n; i++)
        // Only include non-promotions and queen promotions, in order to avoid
        // having the same destination squares multiple times in the array.
        if (!move_promotion(mlist[i]) || move_promotion(mlist[i]) == QUEEN) {
            // For castling moves, adjust the destination square so that it displays
            // correctly when squares are highlighted in the GUI.
            if (move_is_long_castle(mlist[i]))
                sqs[j] = move_to(mlist[i]) + 2;
            else if (move_is_short_castle(mlist[i]))
                sqs[j] = move_to(mlist[i]) - 1;
            else
                sqs[j] = move_to(mlist[i]);
            j++;
        }
    sqs[j] = SQ_NONE;
    return j;
}
- (int)movesFrom:(Square)sq saveInArray:(Move *)mlist {
    assert(square_is_ok(sq));
    assert(mlist != NULL);
    
    int numPossible = self.position->moves_from(sq, mlist);
    return numPossible;
}

#pragma mark - Misc

- (void)dealloc
{
//    delete self.position;
}

- (BOOL)isFlipped
{
    return YES;
}

@end
