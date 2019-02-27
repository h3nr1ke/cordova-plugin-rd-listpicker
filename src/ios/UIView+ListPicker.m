//
//  UIView+ListPicker.h
//  Estapar
//
//  Created by Gabriel Ribeiro on 26/02/2019.
//

#import "UIView+ListPicker.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char subviewsBackgroundColor;

@implementation UIView (ListPicker)

- (void)setSubviewsBackgroundColor:(id)object {
    objc_setAssociatedObject(self, &subviewsBackgroundColor, object, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    for (UIView *subview in self.subviews) {
        [subview setBackgroundColor:object];
    }
}

- (id)subviewsBackgroundColor {
    return objc_getAssociatedObject(self, &subviewsBackgroundColor);
}

@end
