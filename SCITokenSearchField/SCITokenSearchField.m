// VENTokenField.m
//
// Copyright (c) 2014 scireum GmbH
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "SCITokenSearchField.h"

#import <FrameAccessor/FrameAccessor.h>
#import "VENToken.h"
#import "VENBackspaceTextField.h"

static const CGFloat SCITokenSearchFieldDefaultVerticalInset            = 0.0;
static const CGFloat SCITokenSearchFieldDefaultHorizontalInset          = 5.0;
static const CGFloat SCITokenSearchFieldDefaultTokenPadding             = 2.0;
static const CGFloat SCITokenSearchFieldDefaultMinInputWidth            = 80.0;
static const CGFloat SCITokenSearchFieldDefaultMaxHeight                = 150.0;
static const CGFloat SCITokenSearchFieldDefaultMagnifyingGlassPadding   = 2.0;


@interface SCITokenSearchField () <VENBackspaceTextFieldDelegate>

@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) NSMutableArray *tokens;
@property (assign, nonatomic) CGFloat originalHeight;
@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (strong, nonatomic) VENBackspaceTextField *invisibleTextField;
@property (strong, nonatomic) VENBackspaceTextField *inputTextField;
@property (strong, nonatomic) UIColor *colorScheme;
@property (strong, nonatomic) UIView *magnifyingGlassView;

@end


@implementation SCITokenSearchField

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setUpInit];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setUpInit];
}

- (BOOL)becomeFirstResponder
{
    [self reloadData];
    [self inputTextFieldBecomeFirstResponder];
    return YES;
}

- (BOOL)resignFirstResponder
{
    return [self.inputTextField resignFirstResponder];
}

- (void)setUpInit
{
    // Set up default values.
    self.maxHeight = SCITokenSearchFieldDefaultMaxHeight;
    self.verticalInset = SCITokenSearchFieldDefaultVerticalInset;
    self.horizontalInset = SCITokenSearchFieldDefaultHorizontalInset;
    self.tokenPadding = SCITokenSearchFieldDefaultTokenPadding;
    self.minInputWidth = SCITokenSearchFieldDefaultMinInputWidth;
    self.colorScheme = [UIColor blueColor];
    self.inputTextFieldTextColor = [UIColor colorWithRed:38/255.0f green:39/255.0f blue:41/255.0f alpha:1.0f];
    
    self.originalHeight = CGRectGetHeight(self.frame);

    // Add invisible text field to handle backspace when we don't have a real first responder.
    [self layoutInvisibleTextField];

    [self layoutScrollView];
    [self reloadData];
}

- (void)reloadData
{
    BOOL inputFieldShouldBecomeFirstResponder = self.inputTextField.isFirstResponder;

    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.scrollView.hidden = NO;
    [self removeGestureRecognizer:self.tapGestureRecognizer];

    self.tokens = [NSMutableArray array];

    CGFloat currentX = 0;
    CGFloat currentY = 0;

    [self layoutMagnifyingGlassInView:self origin:CGPointMake(self.horizontalInset, self.verticalInset) currentX:&currentX];
    [self layoutTokensWithCurrentX:&currentX currentY:&currentY];
    [self layoutInputTextFieldWithCurrentX:&currentX currentY:&currentY];

    [self adjustHeightForCurrentY:currentY];
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.contentSize.width, currentY + [self heightForToken])];

    [self updateInputTextField];

    if (inputFieldShouldBecomeFirstResponder) {
        [self inputTextFieldBecomeFirstResponder];
    } else {
        [self focusInputTextField];
    }
}

- (void)setPlaceholderText:(NSString *)placeholderText
{
    _placeholderText = placeholderText;
    self.inputTextField.placeholder = _placeholderText;
}

- (void)setInputTextFieldTextColor:(UIColor *)inputTextFieldTextColor
{
    _inputTextFieldTextColor = inputTextFieldTextColor;
    self.inputTextField.textColor = _inputTextFieldTextColor;
}

- (void)setColorScheme:(UIColor *)color
{
    _colorScheme = color;
    self.inputTextField.tintColor = color;
    for (VENToken *token in self.tokens) {
        [token setColorScheme:color];
    }
}

- (NSString *)inputText
{
    return self.inputTextField.text;
}

#pragma mark - View Layout

- (void)layoutScrollView
{
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame))];
    self.scrollView.scrollsToTop = NO;
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.frame) - self.horizontalInset * 2, CGRectGetHeight(self.frame) - self.verticalInset * 2);
    self.scrollView.contentInset = UIEdgeInsetsMake(self.verticalInset,
                                                    self.horizontalInset,
                                                    self.verticalInset,
                                                    self.horizontalInset);
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

    [self addSubview:self.scrollView];
}

- (void)layoutMagnifyingGlassInView:(UIView *)view origin:(CGPoint)origin currentX:(CGFloat *)currentX
{
    [self.magnifyingGlassView removeFromSuperview];
    self.magnifyingGlassView = [self magnifyingGlassView];

    CGRect newFrame = self.magnifyingGlassView.frame;
    newFrame.origin = origin;

    [self.magnifyingGlassView sizeToFit];
    newFrame.size.width = CGRectGetWidth(self.magnifyingGlassView.frame);
    newFrame.origin.y = newFrame.origin.y + (CGRectGetHeight(self.inputTextField.frame) / 2) - (CGRectGetHeight(newFrame) / 2);

    self.magnifyingGlassView.frame = newFrame;
    [view addSubview:self.magnifyingGlassView];
    *currentX += self.magnifyingGlassView.hidden ? CGRectGetMinX(self.magnifyingGlassView.frame) : CGRectGetMaxX(self.magnifyingGlassView.frame) + SCITokenSearchFieldDefaultMagnifyingGlassPadding;
}


- (void)layoutInputTextFieldWithCurrentX:(CGFloat *)currentX currentY:(CGFloat *)currentY
{
    CGFloat inputTextFieldWidth = self.scrollView.contentSize.width - *currentX;
    if (inputTextFieldWidth < self.minInputWidth) {
        inputTextFieldWidth = self.scrollView.contentSize.width;
        *currentY += [self heightForToken];
        *currentX = 0;
    }

    VENBackspaceTextField *inputTextField = self.inputTextField;
    inputTextField.text = @"";
    inputTextField.frame = CGRectMake(*currentX, *currentY + 1, inputTextFieldWidth, [self heightForToken] - 1);
    inputTextField.tintColor = self.colorScheme;
    [self.scrollView addSubview:inputTextField];
}

- (void)layoutTokensWithCurrentX:(CGFloat *)currentX currentY:(CGFloat *)currentY
{
    for (NSUInteger i = 0; i < [self numberOfTokens]; i++) {
        NSString *title = [self titleForTokenAtIndex:i];
        VENToken *token = [[VENToken alloc] init];
        token.colorScheme = self.colorScheme;

        __weak VENToken *weakToken = token;
        token.didTapTokenBlock = ^{
            [self didTapToken:weakToken];
        };

        [token setTitleText:[NSString stringWithFormat:@"%@,", title]];
        [self.tokens addObject:token];

        if (*currentX + token.width <= self.scrollView.contentSize.width) { // token fits in current line
            token.frame = CGRectMake(*currentX, *currentY, token.width, token.height);
        } else {
            *currentY += token.height;
            *currentX = 0;
            CGFloat tokenWidth = token.width;
            if (tokenWidth > self.scrollView.contentSize.width) { // token is wider than max width
                tokenWidth = self.scrollView.contentSize.width;
            }
            token.frame = CGRectMake(*currentX, *currentY, tokenWidth, token.height);
        }
        *currentX += token.width + self.tokenPadding;
        [self.scrollView addSubview:token];
    }
}


#pragma mark - Private

- (CGFloat)heightForToken
{
    return 30;
}

- (void)layoutInvisibleTextField
{
    self.invisibleTextField = [[VENBackspaceTextField alloc] initWithFrame:CGRectZero];
    self.invisibleTextField.delegate = self;
    [self addSubview:self.invisibleTextField];
}

- (void)inputTextFieldBecomeFirstResponder
{
    if (self.inputTextField.isFirstResponder) {
        return;
    }

    [self.inputTextField becomeFirstResponder];
    if ([self.delegate respondsToSelector:@selector(tokenSearchFieldDidBeginEditing:)]) {
        [self.delegate tokenSearchFieldDidBeginEditing:self];
    }
}

- (void)adjustHeightForCurrentY:(CGFloat)currentY
{
    if (currentY + [self heightForToken] > CGRectGetHeight(self.frame)) { // needs to grow
        if (currentY + [self heightForToken] <= self.maxHeight) {
            [self setHeight:currentY + [self heightForToken] + self.verticalInset * 2];
        } else {
            [self setHeight:self.maxHeight];
        }
    } else { // needs to shrink
        if (currentY + [self heightForToken] > self.originalHeight) {
            [self setHeight:currentY + [self heightForToken] + self.verticalInset * 2];
        } else {
            [self setHeight:self.originalHeight];
        }
    }
}

- (VENBackspaceTextField *)inputTextField
{
    if (!_inputTextField) {
        _inputTextField = [[VENBackspaceTextField alloc] init];
        [_inputTextField setKeyboardType:self.inputTextFieldKeyboardType];
        _inputTextField.textColor = self.inputTextFieldTextColor;
        _inputTextField.font = [UIFont fontWithName:@"HelveticaNeue" size:15.5];
        _inputTextField.accessibilityLabel = NSLocalizedString(@"To", nil);
        _inputTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        _inputTextField.tintColor = self.colorScheme;
        _inputTextField.delegate = self;
        _inputTextField.placeholder = self.placeholderText;
        [_inputTextField addTarget:self action:@selector(inputTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        UIImage *clearButtonImage = [UIImage imageNamed:@"clear_Button"];
        UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [clearButton setImage:clearButtonImage forState:UIControlStateNormal];
        [clearButton setFrame:CGRectMake(0, 0, clearButtonImage.size.width, clearButtonImage.size.width)];
        [clearButton addTarget:self action:@selector(clearTextField:) forControlEvents:UIControlEventTouchUpInside];
        UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, clearButtonImage.size.width + 1, clearButtonImage.size.height)];
        [paddingView addSubview:clearButton];
        _inputTextField.rightViewMode = UITextFieldViewModeWhileEditing;
        [_inputTextField setRightView:paddingView];
    }
    return _inputTextField;
}

- (void) clearTextField:(id)sender
{
    self.inputTextField.text = @"";
    [self clearTokenSearchFieldData:self];
}


- (UIView *)magnifyingGlassView {
    if(!_magnifyingGlassView){
        UIImage *magnifyingGlassImage = [UIImage imageNamed:@"magnifying_glass"];
        _magnifyingGlassView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, magnifyingGlassImage.size.width, magnifyingGlassImage.size.height)];
        [_magnifyingGlassView setBackgroundColor:[UIColor colorWithPatternImage:magnifyingGlassImage]];
    }
    return _magnifyingGlassView;
}

- (void)setInputTextFieldKeyboardType:(UIKeyboardType)inputTextFieldKeyboardType
{
    _inputTextFieldKeyboardType = inputTextFieldKeyboardType;
    [self.inputTextField setKeyboardType:self.inputTextFieldKeyboardType];
}

- (void)inputTextFieldDidChange:(UITextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenSearchField:didChangeText:)]) {
        [self.delegate tokenSearchField:self didChangeText:textField.text];
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    [self becomeFirstResponder];
}

- (void)didTapToken:(VENToken *)token
{
    for (VENToken *aToken in self.tokens) {
        if (aToken == token) {
            aToken.highlighted = !aToken.highlighted;
        } else {
            aToken.highlighted = NO;
        }
    }
    [self setCursorVisibility];
}

- (void)unhighlightAllTokens
{
    for (VENToken *token in self.tokens) {
        token.highlighted = NO;
    }
    [self setCursorVisibility];
}

- (void)setCursorVisibility
{
    NSArray *highlightedTokens = [self.tokens filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(VENToken *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.highlighted;
    }]];
    BOOL visible = [highlightedTokens count] == 0;
    if (visible) {
        [self inputTextFieldBecomeFirstResponder];
    } else {
        [self.invisibleTextField becomeFirstResponder];
    }
}

- (void)updateInputTextField
{
    self.inputTextField.placeholder = [self.tokens count] ? nil : self.placeholderText;
}

- (void)focusInputTextField
{
    CGPoint contentOffset = self.scrollView.contentOffset;
    CGFloat targetY = self.inputTextField.y + [self heightForToken] - self.maxHeight;
    if (targetY > contentOffset.y) {
        [self.scrollView setContentOffset:CGPointMake(contentOffset.x, targetY) animated:NO];
    }
}


#pragma mark - Data Source

- (NSString *)titleForTokenAtIndex:(NSUInteger)index
{
    if ([self.dataSource respondsToSelector:@selector(tokenSearchField:titleForTokenAtIndex:)]) {
        return [self.dataSource tokenSearchField:self titleForTokenAtIndex:index];
    }
    return [NSString string];
}

- (NSUInteger)numberOfTokens
{
    if ([self.dataSource respondsToSelector:@selector(numberOfTokensInTokenSearchField:)]) {
        return [self.dataSource numberOfTokensInTokenSearchField:self];
    }
    return 0;
}

- (void)clearTokenSearchFieldData:(SCITokenSearchField *)tokenField
{
    if ([self.dataSource respondsToSelector:@selector(clearTokenSearchFieldData:)]) {
        [self.dataSource clearTokenSearchFieldData:self];
    }
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenSearchField:didEnterText:)]) {
        if ([textField.text length]) {
            [self.delegate tokenSearchField:self didEnterText:textField.text];
        }
    }
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.inputTextField) {
        [self unhighlightAllTokens];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    [self unhighlightAllTokens];
    return YES;
}


#pragma mark - VENBackspaceTextFieldDelegate

- (void)textFieldDidEnterBackspace:(VENBackspaceTextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenSearchField:didDeleteTokenAtIndex:)] && [self numberOfTokens]) {
        BOOL didDeleteToken = NO;
        for (VENToken *token in self.tokens) {
            if (token.highlighted) {
                [self.delegate tokenSearchField:self didDeleteTokenAtIndex:[self.tokens indexOfObject:token]];
                didDeleteToken = YES;
                break;
            }
        }
        if (!didDeleteToken) {
            VENToken *lastToken = [self.tokens lastObject];
            lastToken.highlighted = YES;
        }
        [self setCursorVisibility];
    }
}

@end