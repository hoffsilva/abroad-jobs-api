//
//  ParserController.swift
//  App
//
//  Created by Hoff Henry Pereira da Silva on 02/02/21.
//

import Vapor

struct ParserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("jobs", use: getAllJobs)
    }

    func getAllJobs(_ req: Request) throws -> EventLoopFuture<[[Job]]> {
        try Parser(client: req.client).getJobs(req)
    }
}
