import Fluent
import Vapor

func routes(_ app: Application) throws {
    let parserController = ParserController()
    try app.register(collection: parserController)
}
