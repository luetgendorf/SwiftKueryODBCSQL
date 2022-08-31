//
//  ODBCColumn.swift
//  LoggerAPI
//
//  Created by Richard Jones on 18/03/2019.
//

import Foundation
import LoggerAPI

public class ODBCColumn
{
    init(_ Name:String, DataType:Int16, Colsize:UInt, Decimaldigits:Int16,Nullable:Bool )   {
        self.Name = Name
        self.Datatype  = ODBCSQLType(rawValue: DataType)!
        self.Colsize = Colsize
        self.Decimaldigts = Decimaldigits
        self.Nullable = Nullable
    }
    var Name:String
    var Datatype:ODBCSQLType
    var Colsize:UInt
    var Decimaldigts:Int16!
    var Nullable:Bool

}
