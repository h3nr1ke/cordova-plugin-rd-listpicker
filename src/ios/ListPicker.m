#import "ListPicker.h"
#import "ListPicker-Swift.h"

@implementation ListPicker

@synthesize callbackId = _callbackId;
@synthesize items = _items;

- (void)showPicker:(CDVInvokedUrlCommand*)command {

    [self setup];
    
    self.callbackId = command.callbackId;
    NSDictionary *options = [command.arguments objectAtIndex:0];
  
    // Compiling options with defaults
    NSString *title = [options objectForKey:@"title"] ?: nil;
    NSString *subtitle = [options objectForKey:@"subtitle"] ?: nil;
    
    NSString *cancelButtonLabel = [options objectForKey:@"cancelButtonLabel"] ?: @"Cancel";
    
    NSString *style = [options objectForKey:@"style"] ?: @" ";
    
    CATextLayerAlignmentMode alignment = [options objectForKey:@"alignment"] ?: @(1);
    UIAlertControllerStyle alertStyle = [style  isEqual: @"alert"]
    ? UIAlertControllerStyleAlert
    : UIAlertControllerStyleActionSheet;
    
    // Hold items in an instance variable
    self.items = [options objectForKey:@"items"];

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
                                       
                                       [self sendResults:nil];
                                   }];
    
    [cancelButton setValue:[UIColor lightGrayColor] forKey:@"titleTextColor"];
    
    [alert addAction:cancelButton];
    
    //ITENS BUTTONS
    for (NSDictionary *item in self.items) {
        NSString *text = [item objectForKey:@"text"];
        NSString *value = [item objectForKey:@"value"];
        NSString *icon = [item objectForKey:@"icon"] ?: nil;
        
        UIAlertAction* itemButton = [UIAlertAction actionWithTitle:text
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action)
                                     {
                                         NSLog(@"Pressed %@ with value %@", text, value);
                                         
                                         [self sendResults:value];
                                     }];
        
        [itemButton setValue:alignment forKey:@"titleTextAlignment"];
        [itemButton setValue:[UIColor whiteColor] forKey:@"titleTextColor"];
        
        if (icon != nil) {
            UIImage *iconImage = [UIImage imageNamed:icon];
            [itemButton setValue:iconImage forKey:@"image"];
            [itemButton setValue:[UIColor greenColor] forKey:@"imageTintColor"];
        }
        
        if([options objectForKey:@"selectedValue"]) {
            if ([[options objectForKey:@"selectedValue"] isEqualToString:value]) {
                [itemButton setValue:@(1) forKey:@"checked"];
            }
        }
        
        [alert addAction:itemButton];
    }
    
    [self.viewController presentViewController:alert animated:YES completion:nil];
}

//
// Results
//

- (void)sendResults:(NSString *)selectedValue {
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
            
            // Create OK result otherwise
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:resultDic];
        }
        
        // Call appropriate javascript function
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.callbackId];
    }];
}

//
// Utilities
//

- (BOOL) isViewPortrait {
    return UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
}

- (void)setup {
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setMinimumScaleFactor:0.75];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setAdjustsFontSizeToFitWidth:YES];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setNumberOfLines:2];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]] setLineBreakMode:NSLineBreakByTruncatingTail];
    
    [[UIVisualEffectView appearanceWhenContainedInInstancesOfClasses:@[[UIAlertController class]]]
     setEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    
    ((UIView *)[NSClassFromString(@"_UIAlertControlleriOSActionSheetCancelBackgroundView")
                appearance]).subviewsBackgroundColor = [UIColor darkGrayColor];
}

@end
