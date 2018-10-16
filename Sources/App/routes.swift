import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.get("jobs") { req in
        return try req.make(Parser.self).getJobs(req)
    }
}
