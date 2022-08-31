import Foundation

// MARK: ODBCBinaryParameterConvertible

/// Interface for objects that can be sent as binary parameters of calls to the `PQsendQuery` family of functions
protocol ODBCBinaryParameterConvertible {
    /// Format this object as binary Data for use as a PostgreSQL parameter.
    func asODBCBinaryParameter() -> Data
}

extension Data: ODBCBinaryParameterConvertible {
    public func asODBCBinaryParameter() -> Data {
        return self
    }
}
