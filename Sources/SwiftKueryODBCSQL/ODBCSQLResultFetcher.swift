/**
 Copyright IBM Corporation 2016, 2017
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import SwiftKuery
//import CunixODBC
import unixodbc

import Foundation
import Dispatch
import LoggerAPI

// MARK: PostgreSQLResultFetcher

/// An implementation of query result fetcher.
public class ODBCSQLResultFetcher: ResultFetcher {
   
    private var cols: [ODBCColumn]?
    private var titles: [String]?
    private var row: [Any?]?
    private let MAX_DATA = 100
    private var hstmt:HSTMT!
    
    /// Fetch the next row of the query result. This function is non-blocking.
    ///
    /// - Parameter callback: A closure that accepts a tuple containing an optional array of values of type Any? representing the next row from the query result and an optional Error.
    
    public func fetchNext(callback: @escaping (([Any?]?, Error?)) -> ()) {
        //Log.debug("Called FetchNext")
        
            if let row = row {
                self.row = nil
                return callback((row, nil))
            }
        
            DispatchQueue.global().async {
                let rc = SQLFetch(self.hstmt)
                if rc != SQL_SUCCESS {
                    
                    // no more rows
                    SQLFreeStmt(self.hstmt,SQLUSMALLINT(SQL_DROP));
                    Log.debug("Clear Up - Fetcher")
                    return callback((nil, nil))
                }
                
                return callback((self.buildRow(), nil))
            }
    }
    
    public func fetchTitles(callback: @escaping (([String]?, Error?)) -> ()) {
         callback((self.titles, nil))
    }
    
    public func done() {
        
    }
    
    
    private static func coldef(hstmt:HSTMT!,col:Int) ->ODBCColumn
    {
        let bufferlength:Int=1000
        var namelength:Int16! = 0
        var datatype:Int16! = 0
        var colsize:UInt! = 0
        var decimaldigts:Int16! = 0
        var nullable:Int16! = 0
        var nullablebool:Bool = false
        
        // Todo put MAX_DATA back
        let sqlPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1000)
        
        var rc = SQLDescribeCol(
            hstmt
            ,UInt16(col+1)
            ,sqlPointer
            ,SQLSMALLINT(bufferlength)
            ,&namelength
            ,&datatype
            ,&colsize
            ,&decimaldigts
            , &nullable)
        
        
        // Todo error handler
        /*
         if !MYSQLSUCCESS(rc)    {
         error_out(hstmt: hstmt)
         return nil
         }*/
        
        nullablebool = nullable == 1
        
        let sqlData = Data(bytes: sqlPointer, count: Int(namelength))
        sqlPointer.deallocate()
 
        var name=""
        if let data = String(data: sqlData, encoding: .utf8)    {
            name = data
        }
        let col = ODBCColumn(name, DataType: datatype, Colsize: colsize, Decimaldigits: decimaldigts, Nullable: nullablebool )
        return col
    }
    
    
    internal static func create(hstmt:HSTMT!,  callback: (ODBCSQLResultFetcher) ->()) {
        let resultFetcher = ODBCSQLResultFetcher()
        resultFetcher.hstmt = hstmt
        var columns:Int16=0
        // determine number of columns
        var rc = SQLNumResultCols(hstmt,&columns)
        // todo if there is a problem need to error out
        /*
        if !MYSQLSUCCESS(rc){
            error_out(hstmt:hstmt)
            SQLFreeStmt(hstmt,SQLUSMALLINT(SQL_DROP));
            return
        }*/
        
        
        var columnNames = [String]()
        var cols = [ODBCColumn]()
        for column in 0 ..< columns {
            let coldefinition = coldef(hstmt:hstmt,col:Int(column))
            cols.append(coldefinition)
            columnNames.append(coldefinition.Name)
                Log.debug("*** "+coldefinition.Name)
        }
        Log.debug("In the titles bit")
        resultFetcher.cols = cols
        resultFetcher.titles = columnNames
        
        resultFetcher.row = resultFetcher.buildRow()
        callback(resultFetcher)
    }
    
    private func buildRow() -> [Any?] {
        Log.debug("")
        var row = [Any?]()
        var cbData:Int! = 0  // Output length of data
        let columns:Int = (titles?.count)!
        
        for i in 0..<columns    {
            Log.debug("Processing Column: \(i)")
            let sqlPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: MAX_DATA)
            
            let ret = SQLGetData(hstmt, SQLUSMALLINT(i+1),SQLSMALLINT(SQL_C_CHAR),sqlPointer, MAX_DATA, &cbData)
            
            if ((((ret)&(~1))==0)) {
                /* Handle null columns */
                Log.debug("SQLGetData returned: \(String(cbData))")
                if (cbData == SQL_NULL_DATA) {
                    Log.debug("SQL_NULL_DATA")
                    strcpy(sqlPointer, "")
                    cbData = 0
                }
            }

            let sqlData = Data(bytes: sqlPointer, count: cbData)
                //  TODO - conversion requered
            Log.debug("SQLData: \(sqlData)")
            row.append(convert(sqlData, column: i))
            sqlPointer.deallocate()
        }
        
        
        return row
    }
    private func convert(_ data:Data, column:Int) -> Any?   {
        
        // TODO - need to ensure this happens correctly
        // nil handling
        if data.count == 0 { return nil }
        
        let ourcol = cols![column]
        Log.debug("-- \(ourcol.Name) \(ourcol.Datatype)")
        switch ourcol.Datatype
        {
        case .SQL_BIT:
            if let data = String(data: data, encoding: .utf8)    {
                if let somenum:Int32 = Int32(data) { return somenum == 1 }
            }
            return nil
        case .SQL_UNKNOWN_TYPE:
            fallthrough
        case .SQL_CHAR: // 1
            fallthrough
        case .SQL_NUMERIC ://  2
            fallthrough
        case .SQL_DECIMAL://  3
            fallthrough
        case .SQL_INTEGER:// 4
            if let data = String(data: data, encoding: .utf8)    {
                if let somenum:Int32 = Int32(data) {
                    Log.debug("Convert \(somenum)")
                    return somenum
                }
            }
            return nil
        case .SQL_SMALLINT:// 5
            fallthrough
        case .SQL_FLOAT://  6
            fallthrough
        case .SQL_REAL:// 7
            fallthrough
        case .SQL_DOUBLE:// 8
            fallthrough
        case .SQL_DATETIME:// 9
            fallthrough
        case .SQL_TIME: // 10
            fallthrough
        case .SQL_VARCHAR:// 12
            fallthrough
        default:
            guard let data = String(decoding: data, as: UTF8.self) as String? else {
                Log.debug("Failed to convert \(data)")
                return nil
            }
            Log.debug(" DEFAULT \(data)")
            return data
        }
        return nil
    }
}

