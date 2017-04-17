//
//  Color.swift
//  GPUImageObjcDemo
//
//  Created by Satoru Sasozaki on 1/30/17.
//  Copyright © 2017 Satoru Sasozaki. All rights reserved.
//

import UIKit

class Color: NSObject {
    var name: String
    var uiColor: UIColor
    var cgColor: CGColor {
        return uiColor.cgColor
    }
    
    init(name: String, uiColor: UIColor) {
        self.name = name
        self.uiColor = uiColor
    }
    
    /** Serves the list of colors. */
    class func list() -> [Color] {
        
        
        return [Color(name: "RED", uiColor: UIColor(red: 255/255, green: 56/255, blue: 36/255, alpha: 1.0)),
                Color(name: "FUSCIA", uiColor: UIColor(red: 255/255, green: 40/255, blue: 81/255, alpha: 1.0)),
                Color(name: "ORANGE", uiColor: UIColor(red: 255/255, green: 150/255, blue: 0/255, alpha: 1.0)),
                Color(name: "YELLOW", uiColor: UIColor(red: 255/255, green: 205/255, blue: 0/255, alpha: 1.0)),
                Color(name: "GREEN", uiColor: UIColor(red: 68/255, green: 219/255, blue: 94/255, alpha: 1.0)),
                Color(name: "BAE BLUE", uiColor: UIColor(red: 84/255, green: 199/255, blue: 252/255, alpha: 1.0)),
                Color(name: "BLUE", uiColor: UIColor(red: 0/255, green: 118/255, blue: 255/255, alpha: 1.0)),
                Color(name: "WHITE", uiColor: UIColor.white),
                Color(name: "GRAY", uiColor: UIColor(red: 142/255, green: 142/255, blue: 147/255, alpha: 1.0)),
                Color(name: "BLACK", uiColor: UIColor.black)
        ]
            
                
            
        
    }
}
