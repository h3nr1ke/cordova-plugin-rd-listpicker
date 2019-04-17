#import "ListPicker.h"
#import "UIView+ListPicker.h"

#pragma mark - Constant definitions

#define IS_WIDESCREEN ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )
#define IS_IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
#define DEVICE_ORIENTATION [UIDevice currentDevice].orientation

// UIInterfaceOrientationMask vs. UIInterfaceOrientation
// A function like this isn't available in the API. It is derived from the enum def for
// UIInterfaceOrientationMask.
#define OrientationMaskSupportsOrientation(mask, orientation)   ((mask & (1 << orientation)) != 0)

#pragma mark - ListPicker

@implementation ListPicker {
    NSDictionary *options;
    
    NSString *title;
    NSString *subtitle;
    
    NSString *doneButtonLabel;
    NSString *cancelButtonLabel;
    NSString *clearButtonLabel;
    
    NSString *style;
    NSString *alignment;
    
    NSString *selectedValue;
}

@synthesize callbackId = _callbackId;
@synthesize pickerView = _pickerView;
@synthesize popoverController = _popoverController;
@synthesize modalView = _modalView;
@synthesize items = _items;

#pragma mark - Plugin methods

- (void)pluginInitialize {
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setMinimumScaleFactor:0.75];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setAdjustsFontSizeToFitWidth:YES];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setNumberOfLines:2];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setLineBreakMode:NSLineBreakByTruncatingTail];

    [[UIVisualEffectView appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]]
     setEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];

    [((UIView *)[NSClassFromString(@"_UIAlertControlleriOSActionSheetCancelBackgroundView")
                 appearance]) setSubviewsBackgroundColor:[UIColor colorWithWhite:0 alpha:0.333]];
}

- (void)showPicker:(CDVInvokedUrlCommand*)command {
    self.callbackId = command.callbackId;
    options = [command.arguments objectAtIndex:0];

    title = [options objectForKey:@"title"] ?: nil;
    subtitle = [options objectForKey:@"subtitle"] ?: nil;

    doneButtonLabel = [options objectForKey:@"doneButtonLabel"] ?: @"Done";
    cancelButtonLabel = [options objectForKey:@"cancelButtonLabel"] ?: @"Cancel";
    clearButtonLabel = [options objectForKey:@"clearButtonLabel"] ?: @"Clear";

    style = [options objectForKey:@"style"] ?: @" ";

    alignment = [options objectForKey:@"alignment"] ?: @"1";

    selectedValue = [self getStringValue:[options objectForKey:@"selectedValue"] ?: @""];

    self.items = [options objectForKey:@"items"];
    
    if ([style isEqualToString:@"spinning"] || self.items.count > 30) {
        [self setupPickerView];
    } else {
        [self.commandDelegate runInBackground:^{
            [self setupAlertController];
        }];
    }
}

#pragma mark - Setup

- (void) setupAlertController {
    UIAlertControllerStyle alertStyle = [style  isEqual: @"alert"]
    ? UIAlertControllerStyleAlert
    : UIAlertControllerStyleActionSheet;
    
    //ALERTCONTROLLER
    UIAlertController * alert=[UIAlertController alertControllerWithTitle:title
                                                                  message:subtitle
                                                           preferredStyle:alertStyle];
    
    //CANCEL BUTTON
    UIAlertAction* cancelButton = [UIAlertAction actionWithTitle:cancelButtonLabel
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action)
                                   {
                                       NSLog(@"Pressed CANCEL");
                                       
                                       [self sendResults:nil andIndex:0];
                                   }];
    
    [cancelButton setValue:[UIColor lightGrayColor] forKey:@"titleTextColor"];
    
    [alert addAction:cancelButton];
    
    //ITENS BUTTONS
    for (int i = 0; i < self.items.count; i++) {
        NSDictionary *item = [self.items objectAtIndex:i];
        
        NSString *text = [self getStringValue:[item objectForKey:@"text"]];
        NSObject *value = [item objectForKey:@"value"];
        NSString *icon = [item objectForKey:@"icon"] ?: nil;
        
        UIAlertAction* itemButton = [UIAlertAction actionWithTitle:text
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action)
                                     {
                                         NSLog(@"Pressed %@ with value %@", text, value);
                                         
                                         NSString *strValue = [self getStringValue:value];
                                         
                                         [self sendResults:strValue andIndex:i];
                                     }];
        
        [itemButton setValue:alignment forKey:@"titleTextAlignment"];
        [itemButton setValue:[UIColor whiteColor] forKey:@"titleTextColor"];
        
        if (icon != nil) {
            
            CGFloat scale = [UIScreen mainScreen].scale;
            
            NSString *scaleAppend = [NSString stringWithFormat:@"@%.fx", scale];
            
            NSString* shortFileName = [[icon stringByAppendingString:scaleAppend] stringByAppendingPathExtension: @"png"];
            NSString* fullPath = [@"www" stringByAppendingPathComponent: shortFileName];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            NSString *iconPath = [[NSBundle mainBundle] pathForResource:fullPath ofType:nil];
            
            if ([fileManager fileExistsAtPath:iconPath]) {
                
                NSURL *urlPath = [NSURL fileURLWithPath:iconPath];
                
                NSData *data = [NSData dataWithContentsOfURL:urlPath];
                
                UIImage *iconImage = [[UIImage alloc] initWithData:data scale:scale];
                
                [itemButton setValue:iconImage forKey:@"image"];
            }
        }
        
        if([selectedValue isEqualToString:@""] == NO) {
            NSString *strValue = [self getStringValue:value];
            
            if ([selectedValue isEqualToString:strValue]) {
                [itemButton setValue:@(1) forKey:@"checked"];
            }
        }
        
        [alert addAction:itemButton];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.viewController presentViewController:alert animated:YES completion:nil];
    });
}

- (void) setupPickerView {
    // Initialize the toolbar with Cancel and Done buttons and title
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame: CGRectMake(0, 0, self.viewSize.width, 44)];
    toolbar.barStyle = (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) ? UIBarStyleDefault : UIBarStyleBlackTranslucent;
    NSMutableArray *buttons =[[NSMutableArray alloc] init];
    
    // Create Cancel button
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]initWithTitle:cancelButtonLabel style:UIBarButtonItemStylePlain target:self action:@selector(didDismissWithCancelButton:)];
    [buttons addObject:cancelButton];
    
    // Create title label aligned to center and appropriate spacers
    UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [buttons addObject:flexSpace];
    UILabel *label =[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, 30)];
    [label setTextAlignment:NSTextAlignmentCenter];
    [label setTextColor: (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) ? [UIColor blackColor] : [UIColor whiteColor]];
    [label setFont: [UIFont boldSystemFontOfSize:16]];
    [label setBackgroundColor:[UIColor clearColor]];
    label.text = title;
    UIBarButtonItem *labelButton = [[UIBarButtonItem alloc] initWithCustomView:label];
    [buttons addObject:labelButton];
    [buttons addObject:flexSpace];
    
    // Create Clear button?
    if([[options objectForKey:@"showClearButton"] boolValue]) {
        UIBarButtonItem *clearButton = [[UIBarButtonItem alloc]initWithTitle:clearButtonLabel style:UIBarButtonItemStylePlain target:self action:@selector(didDismissWithClearButton:)];
        [buttons addObject:clearButton];
    }
    
    // Create Done button
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:doneButtonLabel style:UIBarButtonItemStyleDone target:self action:@selector(didDismissWithDoneButton:)];
    [buttons addObject:doneButton];
    [toolbar setItems:buttons animated:YES];
    
    // Initialize the picker
    self.pickerView = [[UIPickerView alloc] initWithFrame:CGRectMake(0, 40.0f, self.viewSize.width, 216)];
    self.pickerView.showsSelectionIndicator = YES;
    self.pickerView.delegate = self;
    
    // Define selected value
    if([options objectForKey:@"selectedValue"]) {
        NSString *selectedValue = [self getStringValue:[options objectForKey:@"selectedValue"]];
        int i = [self getRowWithValue:selectedValue];
        if (i != -1) [self.pickerView selectRow:i inComponent:0 animated:NO];
    }
    
    // Initialize the View that should conain the toolbar and picker
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.viewSize.width, 260)];
    if(NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1) {
        [view setBackgroundColor:[UIColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1.0]];
    }
    [view addSubview: toolbar];
    
    //ios7 picker draws a darkened alpha-only region on the first and last 8 pixels horizontally, but blurs the rest of its background.  To make the whole popup appear to be edge-to-edge, we have to add blurring to the remaining left and right edges.
    if ( NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_6_1 )
    {
        CGRect f = CGRectMake(0, toolbar.frame.origin.y, 8, view.frame.size.height - toolbar.frame.origin.y);
        UIToolbar *leftEdge = [[UIToolbar alloc] initWithFrame:f];
        f.origin.x = view.frame.size.width - 8;
        UIToolbar *rightEdge = [[UIToolbar alloc] initWithFrame:f];
        [view insertSubview:leftEdge atIndex:0];
        [view insertSubview:rightEdge atIndex:0];
    }
    
    [view addSubview:self.pickerView];
    
    // Check if device is iPad to display popover
    if ( IS_IPAD ) {
        return [self presentPopoverForView:view];
    } else {
        return [self presentModalViewForView:view];
    }
}

#pragma mark - Present methods

-(void)presentModalViewForView:(UIView *)view {
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRotate:)
                                                 name:UIApplicationWillChangeStatusBarOrientationNotification
                                               object:nil];
    
    CGRect viewFrame = CGRectMake(0, 0, self.viewSize.width, self.viewSize.height);
    [view setFrame: CGRectMake(0, viewFrame.size.height, viewFrame.size.width, 260)];
    
    // Create the modal view to display
    self.modalView = [[UIView alloc] initWithFrame: viewFrame];
    [self.modalView setBackgroundColor:[UIColor clearColor]];
    [self.modalView addSubview: view];
    
    // Add the modal view to current controller
    [self.webView.superview addSubview:self.modalView];
    [self.webView.superview bringSubviewToFront:self.modalView];
    
    //Present the view animated
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options: 0
                     animations:^{
                         [self.modalView.subviews[0] setFrame: CGRectOffset(viewFrame, 0, viewFrame.size.height - 260)];;
                         [self.modalView setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:0.5]];
                     }
                     completion:nil];
}

-(void)presentPopoverForView:(UIView *)view {
    
    // Create a generic content view controller
    UIViewController* popoverContent = [[UIViewController alloc] initWithNibName:nil bundle:nil];
    popoverContent.view = view;
    
    // Resize the popover to the view's size
    popoverContent.preferredContentSize = view.frame.size;
    
    // Create a popover controller
    self.popoverController = [[UIPopoverController alloc] initWithContentViewController:popoverContent];
    self.popoverController.delegate = self;
    
    // display the picker at the center of the view
    CGRect sourceRect = CGRectMake(self.webView.superview.center.x, self.webView.superview.center.y, 1, 1);
    
    //present the popover view non-modal with a
    //refrence to the button pressed within the current view
    [self.popoverController presentPopoverFromRect:sourceRect
                                            inView:self.webView.superview
                          permittedArrowDirections: 0
                                          animated:YES];
    
}

#pragma mark - Dismiss methods

- (void) didRotate:(NSNotification *)notification
{
    UIInterfaceOrientationMask supportedInterfaceOrientations = (UIInterfaceOrientationMask) [[UIApplication sharedApplication]
                                                                                              supportedInterfaceOrientationsForWindow:
                                                                                              [UIApplication sharedApplication].keyWindow];
    
    if (OrientationMaskSupportsOrientation(supportedInterfaceOrientations, DEVICE_ORIENTATION)) {
        // Check if device is iPad
        if ( IS_IPAD ) {
            [self dismissPopoverController:self.popoverController withButtonIndex:0 animated:YES];
        } else {
            [self dismissModalView:self.modalView withButtonIndex:0 animated:YES];
        }
    }
}

// Picker with toolbar dismissed with done
- (IBAction)didDismissWithDoneButton:(id)sender {
    
    // Check if device is iPad
    if ( IS_IPAD ) {
        // Emulate a new delegate method
        [self dismissPopoverController:self.popoverController withButtonIndex:1 animated:YES];
    } else {
        [self dismissModalView:self.modalView withButtonIndex:1 animated:YES];
    }
}

// Picker with toolbar dismissed with cancel
- (IBAction)didDismissWithCancelButton:(id)sender {
    
    // Check if device is iPad
    if ( IS_IPAD ) {
        // Emulate a new delegate method
        [self dismissPopoverController:self.popoverController withButtonIndex:0 animated:YES];
    } else {
        [self dismissModalView:self.modalView withButtonIndex:0 animated:YES];
    }
}

// Picker with toolbar dismissed with clear
- (IBAction)didDismissWithClearButton:(id)sender {
    // Check if device is iPad
    if ( IS_IPAD ) {
        // Emulate a new delegate method
        [self dismissPopoverController:self.popoverController withButtonIndex:2 animated:YES];
    } else {
        [self dismissModalView:self.modalView withButtonIndex:2 animated:YES];
    }
}

// Popover generic dismiss - iPad
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    
    // Simulate a cancel click
    [self sendResultsFromPickerView:self.pickerView withButtonIndex:0];
}

// Popover emulated button-powered dismiss - iPad
- (void)dismissPopoverController:(UIPopoverController *)popoverController withButtonIndex:(NSInteger)buttonIndex animated:(Boolean)animated {
    
    // Manually dismiss the popover
    [popoverController dismissPopoverAnimated:animated];
    
    // Send the result according to the button selected
    [self sendResultsFromPickerView:self.pickerView withButtonIndex:buttonIndex];
}

// View generic dismiss - iPhone (iOS8)
- (void)dismissModalView:(UIView *)modalView withButtonIndex:(NSInteger)buttonIndex animated:(Boolean)animated {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillChangeStatusBarOrientationNotification
                                                  object:nil];
    
    //Hide the view animated and then remove it.
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options: 0
                     animations:^{
                         CGRect viewFrame = CGRectMake(0, 0, self.viewSize.width, self.viewSize.height);
                         [self.modalView.subviews[0] setFrame: CGRectOffset(viewFrame, 0, viewFrame.size.height)];
                         [self.modalView setBackgroundColor:[UIColor clearColor]];
                     }
                     completion:^(BOOL finished) {
                         [self.modalView removeFromSuperview];
                     }];
    
    // Retreive pickerView
    [self sendResultsFromPickerView:self.pickerView withButtonIndex:buttonIndex];
}

#pragma mark - Results

- (void)sendResults:(NSString *)selectedValue andIndex:(int)index {
    [[UIVisualEffectView appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]]
     setEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
    
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult;
        
        if (selectedValue == nil) {
            // Create ERROR result
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        } else {
            // Create Plugin Result
            NSMutableDictionary *resultDic = [NSMutableDictionary dictionary];
            
            [resultDic setValue:@"selectedValue" forKey:@"action"];
            [resultDic setValue:selectedValue forKey:@"value"];
            [resultDic setValue:@(index).stringValue forKey:@"index"];
            
            // Create OK result otherwise
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDic];
        }
        
        // Call appropriate javascript function
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }];
}

- (void)sendResultsFromPickerView:(UIPickerView *)pickerView withButtonIndex:(NSInteger)buttonIndex {
    [[UIVisualEffectView appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]]
     setEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight]];
    
    // Build returned result
    NSInteger selectedRow = [pickerView selectedRowInComponent:0];
    
    [self.commandDelegate runInBackground:^{
        // Create Plugin Result
        CDVPluginResult* pluginResult;
        
        if (selectedRow >= [self.items count])
        {
            //No element exists at this index, you will receive index out of bounds exception and your application will crash if you ask for object at current indexPath.row.
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            return [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        } else {
            NSString *selectedValue = [[self.items objectAtIndex:selectedRow] objectForKey:@"value"];
            
            if (buttonIndex == 0) {
                // Create ERROR result if cancel was clicked
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
            }else{
                NSMutableDictionary *resultDic = [NSMutableDictionary dictionary];
                if(buttonIndex == 1){
                    [resultDic setValue:@"selectedValue" forKey:@"action"];
                    [resultDic setValue:selectedValue forKey:@"value"];
                    [resultDic setValue:@(selectedRow).stringValue forKey:@"index"];
                }else{
                    [resultDic setValue:@"clear" forKey:@"action"];
                }
                
                // Create OK result otherwise
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDic];
            }
            
            // Call appropriate javascript function
            return [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
        }
    }];
}

#pragma mark - UIPickerViewDelegate

// Listen picker selected row
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
}

// Tell the picker how many rows are available for a given component
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [self.items count];
}

// Tell the picker how many components it will have
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// Tell the picker the title for a given component
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [[self.items objectAtIndex:row] objectForKey:@"text"];
}

// Called by the picker view when it needs the view to use for a given row in a given component
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {

      UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, pickerView.frame.size.width - 30, 44)];

      [label setMinimumScaleFactor:0.75];
      label.adjustsFontSizeToFitWidth = YES;
      label.numberOfLines = 2;
      label.lineBreakMode = NSLineBreakByTruncatingTail;
      label.textAlignment = NSTextAlignmentCenter;
      label.textColor = UIColor.whiteColor;

      label.text = [[self.items objectAtIndex:row] objectForKey:@"text"];
      [label sizeToFit];

      return label;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    return 64;
}

// Tell the picker the width of each row for a given component
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    return pickerView.frame.size.width - 30;
}

#pragma mark - View Utilities

- (CGSize)viewSize
{
    if ( IS_IPAD )
    {
        return CGSizeMake(320, 320);
    }
    
#if defined(__IPHONE_8_0)
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        //iOS 7.1 or earlier
        if ( [self isViewPortrait] )
            return CGSizeMake(320 , IS_WIDESCREEN ? 568 : 480);
        return CGSizeMake(IS_WIDESCREEN ? 568 : 480, 320);
        
    }else{
        //iOS 8 or later
        return [[UIScreen mainScreen] bounds].size;
    }
#else
    if ( [self isViewPortrait] )
        return CGSizeMake(320 , IS_WIDESCREEN ? 568 : 480);
    return CGSizeMake(IS_WIDESCREEN ? 568 : 480, 320);
#endif
}

- (BOOL) isViewPortrait {
    return UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
}

#pragma mark - Value Utilities

- (int)getRowWithValue:(NSString * )selectedValue {
    for(int i = 0; i < [self.items count]; i++) {
        NSDictionary *item = [self.items objectAtIndex:i];
        NSString *rowValue = [self getStringValue:[item objectForKey:@"value"]];
        if([selectedValue isEqualToString:rowValue]) {
            return i;
        }
    }
    return -1;
}

- (NSString*)getStringValue:(NSObject*)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [((NSNumber*)value) stringValue];
    } else {
        return (NSString*)value;
    }
}

@end
