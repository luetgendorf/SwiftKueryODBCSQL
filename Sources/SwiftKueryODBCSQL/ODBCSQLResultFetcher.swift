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
import CunixODBC
import Foundation
import Dispatch

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
        //print("Called FetchNext")
        
            if let row = row {
                self.row = nil
                return callback((row, nil))
            }
        
            DispatchQueue.global().async {
                var rc = SQLFetch(self.hstmt)
                if rc != SQL_SUCCESS {
                    
                    // no more rows
                    SQLFreeStmt(self.hstmt,SQLUSMALLINT(SQL_DROP));
                    print ("Clear Up - Fetcher")
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
    
    private static func colname(hstmt:HSTMT!,col:Int) ->String!
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
        
        var rc = CunixODBC.SQLDescribeCol(
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
        
        if let data = String(data: sqlData, encoding: .utf8)    {
           return data
        }
        return nil
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
        
        var rc = CunixODBC.SQLDescribeCol(
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
        let col=ODBCColumn()
        col.Name=name
        col.Colsize = colsize
        col.Datatype = datatype
        col.Decimaldigts = decimaldigts
        col.Nullable = nullablebool
        return col
    }
    
    
    internal static func create(hstmt:HSTMT!,  callback: (ODBCSQLResultFetcher) ->()) {
        let resultFetcher = ODBCSQLResultFetcher()
        resultFetcher.hstmt = hstmt
        var columns:Int16=0
        // determine number of columns
        var rc = CunixODBC.SQLNumResultCols(hstmt,&columns)

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
               // print("*** "+colname)
        }
        
        resultFetcher.cols = cols
        resultFetcher.titles = columnNames
        
        resultFetcher.row = resultFetcher.buildRow()
        callback(resultFetcher)
    }
    
    private func buildRow() -> [Any?] {
        
        var row = [Any?]()
        var cbData:Int! = 0  // Output length of data
        let columns:Int = (titles?.count)!
        
        for i in 0..<columns    {
            let sqlPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: MAX_DATA)
            
            SQLGetData(hstmt, SQLUSMALLINT(i+1),SQLSMALLINT(SQL_C_CHAR),sqlPointer, MAX_DATA, &cbData)
            let sqlData = Data(bytes: sqlPointer, count: cbData)
            if let data = String(data: sqlData, encoding: .utf8)    {
                //  TODO - conversion requered
                // row.append(PostgreSQLResultFetcher.convert(queryResult, row: 0, column: column))
                
                row.append(data)
            }
            sqlPointer.deallocate()
        }
        return row
    }
}

