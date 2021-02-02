import Fluent
import Vapor

func routes(_ app: Application) throws {
  app.get("jobs") { req -> String in
    try req.make(Parser.self).getJobs(req)
  }
}

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get("jobs") { req in
        return try req.make(Parser.self).getJobs(req)
    }
}
