//
//  ParserController.swift
//  App
//
//  Created by Hoff Henry Pereira da Silva on 02/02/21.
//

import Vapor
import Fluent

struct ParserController: RouteCollection {
    
  func boot(routes: RoutesBuilder) throws {
    routes.get(use: getAllJobs)
  }
  
  func getAllJobs(_ req: Request) throws -> EventLoopFuture<[[Job]]> {
    Parser(client: req.client).getJobs()
  }
  
}
