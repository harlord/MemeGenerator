//
//  DataRequest.swift
//  MemeGenerator
//
//  Created by Harold Hernandez on 3/4/18.
//  Copyright © 2018 Harold Hernandez. All rights reserved.
//

import Alamofire

public enum DecodableResponseError: Error {
  case network(error: Error)
  case serialization(error: Error)
  case decoding(error: Error)
}

extension DataRequest {

  public func responseTyped<T: Decodable>
    (queue: DispatchQueue? = nil,
     options: JSONSerialization.ReadingOptions = .allowFragments,
     callback: @escaping (OperationResult<[T]>) -> Void) {
    
    responseString { (response) in

      self.manageResponse(response: response) { result in

        switch result {
        case let .succeeded(data):
          do {
            let typedResponse = try JSONDecoder().decode([T].self, from: data)
            return callback(OperationResult.succeeded(typedResponse))
          } catch {
            print("Unexpected error: \(error).")
            let platformError = ErrorPlatform.decode(error: error)
            return callback(OperationResult.failed(platformError))
          }

        case let .failed(errorPlatform):
          callback(OperationResult.failed(errorPlatform))
        }
      }
    }
  }

  public func responseTyped<T: Decodable>
    (queue: DispatchQueue? = nil,
     options: JSONSerialization.ReadingOptions = .allowFragments,
     callback: @escaping (OperationResult<T>) -> Void) {

    responseString { (response) in

      self.manageResponse(response: response) { result in

        switch result {
        case let .succeeded(data):
          do {
            let typedResponse = try JSONDecoder().decode(T.self, from: data)
            return callback(OperationResult.succeeded(typedResponse))
          } catch {
            print("Unexpected error: \(error).")
            let platformError = ErrorPlatform.decode(error: error)
            return callback(OperationResult.failed(platformError))
          }

        case let .failed(errorPlatform):
          callback(OperationResult.failed(errorPlatform))
        }
      }
    }
  }

  fileprivate func decodeMemeBase(data: Data, failed: @escaping (OperationResult<Data>) -> Void) -> Bool {
    do {
      let decoded = try JSONDecoder().decode(MemeBase.self, from: data)
      return decoded.success
    } catch {
      print("Unexpected error: \(error).")
      let platformError = ErrorPlatform.decode(error: error)
      failed(OperationResult.failed(platformError))
      return false
    }
  }

  fileprivate func manageErrorPlatform(data: Data, failed: @escaping (OperationResult<Data>) -> Void) {
    do {
      let decoded = try JSONDecoder().decode(ErrorModel.self, from: data)
      failed(OperationResult.failed(ErrorPlatform.platform(error: decoded)))
    } catch {
      print("Unexpected error: \(error).")
      let platformError = ErrorPlatform.decode(error: error)
      failed(OperationResult.failed(platformError))
    }
  }

  func manageResponse
    (response: DataResponse<String>,
     callback: @escaping (OperationResult<Data>) -> Void) {

    let codeSuccess = response.request?.httpMethodTyped.codeSuccess ?? HTTPMethod.get.codeSuccess

    switch response.result {
    case let .success(responsetext):
      print("Response: \(responsetext)")
      let data = response.data ?? Data()

      let success = decodeMemeBase(data: data) { error in
        callback(error)
        return
      }

      let statusCode = response.response?.statusCode ?? 0

      switch (statusCode, success) {
      case (codeSuccess, true):
        callback(OperationResult.succeeded(data))

      case (codeSuccess, false):
        manageErrorPlatform(data: data) { error in
          callback(error)
        }

      default:
        manageErrorPlatform(data: data) { error in
          callback(error)
        }
      }

    case let .failure(error):
      switch response.response?.statusCode ?? 0 {
      case 500:
        return callback(OperationResult.failed(ErrorPlatform.unknowError))

      default: callback(OperationResult.failed(ErrorPlatform.network(error: error)))
      }
    }
  }
}
