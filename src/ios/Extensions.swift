//
//  Extensions.swift
//  Pickers
//
//  Created by Gabriel Ribeiro on 25/02/2019.
//  Copyright © 2019 TVF Software. All rights reserved.
//

import Foundation
import UIKit

public extension UIView {
    private struct AssociatedKey {
        static var subviewsBackgroundColor = "subviewsBackgroundColor"
    }
    
    @objc(ListPicker) dynamic var subviewsBackgroundColor: UIColor? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKey.subviewsBackgroundColor) as? UIColor
        }
        
        set {
            objc_setAssociatedObject(self,
                                     &AssociatedKey.subviewsBackgroundColor,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            subviews.forEach { $0.backgroundColor = newValue }
        }
    }
}
