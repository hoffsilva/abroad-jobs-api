import Foundation
import SwiftSoup
import Vapor

final class Parser {
    let client: Client

    init(client: Client) {
        self.client = client
    }

    public func getJobs(_ request: Request) throws -> EventLoopFuture<[[Job]]> {
        var futureJobs: [EventLoopFuture<[Job]>] = []
        futureJobs.append(getJobsFromRemoteOK())
        futureJobs.append(getJobsFromLandingJobs(request))
        futureJobs.append(getJobsFromCryptoJobs())
        futureJobs.append(getJobsFromVanhack())
        futureJobs.append(getiOSDevJobs())
        futureJobs.shuffle()
        return futureJobs.flatten(on: request.eventLoop)
    }

    func getJobsFromRemoteOK() -> EventLoopFuture<[Job]> {
        let url = URI(string: Constants.remoteOkURL)
        return client.get(url)
            .map { response in
                do {
                    let html = response.description
                    let document = try SwiftSoup.parse(html)
                    let tbody = try document.select("tbody tr").array()
                    let pairs: [(Element, Element?)] = stride(from: 0, to: tbody.count, by: 2).map {
                        (tbody[$0], $0 < tbody.count - 1 ? tbody[$0.advanced(by: 1)] : nil)
                    }
                    var jobs = [Job]()
                    for (trData, trDescription) in pairs {
                        let arrayData = try trData.select("td").array()
                        var tags = [""]
                        guard arrayData.count >= 3 else {
                            continue
                        }
                        let jobTitle = try arrayData[1].select("h2").text()
                        let companyLogoURL = try arrayData[0].select("a img").attr("src")
                        let companyName = try arrayData[1].select("a h3").text()
                        let applyURL = try "https://remoteok.io" + arrayData[1].select("a").attr("href")
                        if arrayData.count > 3 {
                            tags = try arrayData[3].select("h3").array().map { try $0.text() }
                        }
                        var jobDescription = try trDescription?.text().components(separatedBy: " See more jobs at").first ?? ""
                        jobDescription = jobDescription.replacingOccurrences(of: "{linebreak}", with: "\n")
                        let job = Job(jobTitle: jobTitle, companyLogoURL: companyLogoURL, companyName: companyName, jobDescription: jobDescription, applyURL: applyURL, tags: tags, source: Constants.remoteOkSource)
                        jobs.append(job)
                    }
                    return jobs
                } catch {
                    return []
                }
            }
    }

    private func getiOSDevJobs() -> EventLoopFuture<[Job]> {
        let url = URI(string: Constants.iosDevJobsURL)
        return client
            .post(url, headers: [:]) { request in
                try request.content.encode(["per_page": "1000", "show_pagination": "false"], as: .formData)
            }
            .flatMapThrowing { response in
                try response.content.decode(ResultOfiOSDevJobs.self)
            }
            .map { json in
                do {
                    let document = try SwiftSoup.parse(json.html)
                    let jobsList = try document.select("li").array()
                    var jobs = [Job]()

                    for job in jobsList {
                        let title = try job.select("h3").text()
                        let description = try job.select("div.job-description").text()
                        let companyURL = ""
                        let applyURL = try job.select("a").attr("href")
                        let tagsHTML = try job.select("div.tags").select("span").array()
                        var tags = try tagsHTML.map { element -> String in
                            try element.text()
                        }
                        tags.append("iOS")
                        jobs.append(
                            Job(
                                jobTitle: title,
                                companyLogoURL: companyURL,
                                companyName: String(title.split(separator: "@").last ?? ""),
                                jobDescription: description,
                                applyURL: applyURL,
                                tags: tags,
                                source: Constants.iosDevJobs
                            ))
                    }

                    return jobs.filter { job in
                        !job.jobTitle.isEmpty
                    }
                } catch {
                    return []
                }
            }
    }

    private func getJobsFromVanhack() -> EventLoopFuture<[Job]> {
        let url = URI(string: Constants.vanhackJobsURL)
        var jobs = [Job]()
        return client.get(url)
            .flatMapThrowing { response in
                try response.content.decode(ResultOfVanhack.self)
            }
            .map { json in
                for vhJob in json.result.items {
                    jobs.append(Job(vhJob))
                }
                return jobs
            }
    }

    private func getJobsFromLandingJobs(_ req: Request) -> EventLoopFuture<[Job]> {
        let url = URI(string: Constants.landingJobsURL)
        return client.get(url)
            .flatMapThrowing { response in
                try response.content.decode(LandingJobsData.self)
            }
            .flatMap { json in
                var jobs = [EventLoopFuture<[Job]>]()
                let firstPageJobs = json.offers.map { Job($0) }

                jobs.append(req.eventLoop.future(firstPageJobs))

                for page in 2 ... json.numberOfPages {
                    let url = URI(string: Constants.landingJobsSearchURL + String(page))

                    jobs.append(self.client.get(url)
                        .flatMapThrowing { response in
                            try response.content.decode(LandingJobsData.self)
                        }
                        .map { json in
                            let jobs = json.offers.map { Job($0) }
                            return jobs
                        })
                }

                return jobs.flatten(on: req.eventLoop).map { futureJobs in
                    Array(futureJobs.joined())
                }
            }
    }

    private func getJobsFromCryptoJobs() -> EventLoopFuture<[Job]> {
        let url = URI(string: Constants.cryptoJobsURL)
        var jobs = [Job]()
        return client.get(url)
            .map { (response: ClientResponse) in
                do {
                    let html = response.description
                    let document = try SwiftSoup.parse(html)
                    let htmlJobsList = try document.select("article ul").array()

                    for (index, htmlJob) in htmlJobsList.enumerated() {
                        if index == 1 {
                            let cryptoJobs = try htmlJob.select("li").array()
                            for cryptoJob in cryptoJobs {
                                let jobTitle = try cryptoJob.select("li span a.jobTitle").text()
                                let companyName = try cryptoJob.select("li span a.companyName").text()
                                let applyURL = try Constants.cryptoJobsURL + cryptoJob.select("li span a.jobTitle").attr("href")
                                let tags = ["Tag not available"]
                                let jobDescription = "Description not available"
                                let job = Job(
                                    jobTitle: jobTitle,
                                    companyLogoURL: "",
                                    companyName: companyName,
                                    jobDescription: jobDescription,
                                    applyURL: applyURL,
                                    tags: tags,
                                    source: Constants.cryptoJobsSource
                                )
                                jobs.append(job)
                            }
                        }
                    }
                    return jobs
                } catch {
                    return []
                }
            }
    }
}

struct ParserRepositoryFactory {
    var make: ((Request) -> Parser)?
    mutating func use(_ make: @escaping ((Request) -> Parser)) {
        self.make = make
    }
}

extension Parser {
    func getIOSDevsBody() -> Data {
        let parameters = [
            [
                "key": "per_page",
                "value": "1000",
                "type": "text",
            ],
            [
                "key": "show_pagination",
                "value": "false",
                "type": "text",
            ],
        ] as [[String: Any]]

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = ""
        for param in parameters {
            if param["disabled"] == nil {
                let paramName = param["key"]!
                body += "--\(boundary)\r\n"
                body += "Content-Disposition:form-data; name=\"\(paramName)\""
                if param["contentType"] != nil {
                    body += "\r\nContent-Type: \(param["contentType"] as! String)"
                }
                let paramType = param["type"] as! String
                if paramType == "text" {
                    let paramValue = param["value"] as! String
                    body += "\r\n\r\n\(paramValue)\r\n"
                } else {
                    let paramSrc = param["src"] as! String
                    let fileData = try! NSData(contentsOfFile: paramSrc, options: []) as Data
                    let fileContent = String(data: fileData, encoding: .utf8)!
                    body += "; filename=\"\(paramSrc)\"\r\n"
                        + "Content-Type: \"content-type header\"\r\n\r\n\(fileContent)\r\n"
                }
            }
        }
        body += "--\(boundary)--\r\n"
        return body.data(using: .utf8)!
    }
}
