import Foundation
import SwiftSoup
import Vapor

final class Parser {
    let client: Client
    
    init(client: Client) {
        self.client = client
    }
    
    public func getJobs(_ worker: Worker) throws -> Future<[[Job]]> {
        var futureJobs: [Future<[Job]>] = []
        futureJobs.append(try getJobsFromRemoteOK(on: worker))
        futureJobs.append(try getJobsFromLandingJobs(on: worker))
        futureJobs.append(try getJobsFromCryptoJobs(on: worker))
        futureJobs.append(try getJobsFromVanhack(on: worker))
        futureJobs.append(try getJobsRemotelyAwesome(on: worker))
        return futureJobs.flatten(on: worker)
    }
    
    private func getJobsFromRemoteOK(on _: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: Constants.remoteOkURL) else {
            throw Abort(.internalServerError)
        }
        return client.get(url).map { response in
            let html = response.http.body.description
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
        }
    }
    
    private func getJobsRemotelyAwesome(on _: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: Constants.iosDevJobsURL) else {
            throw Abort(.internalServerError)
        }
        
        return client.post(url, headers: [:]) { (request) in
            try request.content.encode(["per_page": "1000", "show_pagination": "false"], as: .formData)
        }.map { response in
            guard let data = response.http.body.data else {
                return [Job]()
            }
            let iOSDevJobsHTML = try JSONDecoder().decode(ResultOfiOSDevJobs.self, from: data)
            let document = try SwiftSoup.parse(iOSDevJobsHTML.html)
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
                        source: Constants.iosDevJobs))
            }
            
            return jobs.filter { job in
                !job.jobTitle.isEmpty
            }
        }
    }
    
    private func getJobsFromVanhack(on _: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: Constants.vanhackJobsURL) else {
            throw Abort(.internalServerError)
        }
        var jobs = [Job]()
        return client.get(url).map { response in
            guard let data = response.http.body.data else {
                return []
            }
            let vhJobs = try JSONDecoder().decode(ResultOfVanhack.self, from: data)
            for vhJob in vhJobs.result.items {
                jobs.append(Job(vhJob))
            }
            return jobs
        }
    }
    
    private func getJobsFromLandingJobs(on worker: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: Constants.landingJobsURL) else {
            return worker.future([])
        }
        
        return client.get(url).flatMap { response in
            guard let data = response.http.body.data else {
                return worker.future([])
            }
            
            var jobs = [Future<[Job]>]()
            let landingJobsData = try JSONDecoder().decode(LandingJobsData.self, from: data)
            let firstPageJobs = landingJobsData.offers.map { Job($0) }
            jobs.append(worker.future(firstPageJobs))
            
            for page in 2 ... landingJobsData.numberOfPages {
                guard let url = URL(string: Constants.landingJobsSearchURL + String(page)) else {
                    break
                }
                
                jobs.append(self.client.get(url).map { response in
                    guard let data = response.http.body.data else {
                        return []
                    }
                    
                    let landingJobsData = try JSONDecoder().decode(LandingJobsData.self, from: data)
                    let jobs = landingJobsData.offers.map { Job($0) }
                    return jobs
                })
            }
            
            return jobs.flatten(on: worker).map { futureJobs in
                Array(futureJobs.joined())
            }
        }
    }
    
    private func getJobsFromCryptoJobs(on worker: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: Constants.cryptoJobsURL) else {
            return worker.future([])
        }
        
        var jobs = [Job]()
        return client.get(url).map { response in
            guard let data = response.http.body.data else {
                return []
            }
            
            let html = response.http.body.description
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
                            source: Constants.cryptoJobsSource)
                        jobs.append(job)
                    }
                }
            }
            return jobs
        }
    }
    
    
}

extension Parser: ServiceType {
    static func makeService(for worker: Container) throws -> Parser {
        return try Parser(client: worker.make())
    }
}

extension Parser {
    
    func getIOSDevsBody() -> Data {
        let parameters = [
          [
            "key": "per_page",
            "value": "1000",
            "type": "text"
          ],
          [
            "key": "show_pagination",
            "value": "false",
            "type": "text"
          ]] as [[String : Any]]

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
              let fileData = try! NSData(contentsOfFile:paramSrc, options:[]) as Data
              let fileContent = String(data: fileData, encoding: .utf8)!
              body += "; filename=\"\(paramSrc)\"\r\n"
                + "Content-Type: \"content-type header\"\r\n\r\n\(fileContent)\r\n"
            }
          }
        }
        body += "--\(boundary)--\r\n";
        return body.data(using: .utf8)!
    }
    
}


