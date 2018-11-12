import Vapor
import SwiftSoup

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
        
        return futureJobs.flatten(on: worker)
    }
    
    private func getJobsFromRemoteOK(on worker: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: "https://remoteok.io/remote-jobs") else {
            throw Abort(.internalServerError)
        }
        return client.get(url).map { response in
            let html = response.http.body.description
            let document = try SwiftSoup.parse(html)
            let tbody = try document.select("tbody tr").array()
            let pairs: [(Element, Element?)] = stride(from: 0, to: tbody.count, by: 2).map {
                (tbody[$0], $0 < tbody.count-1 ? tbody[$0.advanced(by: 1)] : nil)
            }
            var jobs = [Job]()
            for (trData, trDescription) in pairs {
                let arrayData = try trData.select("td").array()
                guard arrayData.count >= 3 else {
                    continue
                }
                let jobTitle = try arrayData[1].select("a h2").text()
                let companyLogoURL = try arrayData[0].select("div").attr("data-original")
                let companyName = try arrayData[1].select("a h3").text()
                let applyURL = try "https://remoteok.io" + arrayData[1].select("a").attr("href")
                let tags = try arrayData[3].select("h3").array().map { try $0.text() }
                let jobDescription = try trDescription?.text().components(separatedBy: " See more jobs at").first ?? ""
                
                let job = Job(jobTitle: jobTitle, companyLogoURL: companyLogoURL, companyName: companyName, jobDescription: jobDescription, applyURL: applyURL, tags: tags, source: "remote-ok")
                jobs.append(job)
            }
            return jobs
        }
    }
    
    private func getJobsFromLandingJobs(on worker: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: "https://landing.jobs/jobs/search.json") else {
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
            
            for page in (2...landingJobsData.numberOfPages) {
                guard let url = URL(string: "https://landing.jobs/jobs/search.json?page=\(page)") else {
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
                return Array(futureJobs.joined())
            }
        }
    }
    
    private func getJobsFromCryptoJobs(on worker: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: "https://cryptojobslist.com/job/filter?remote=true") else {
            return worker.future([])
        }
        
        var jobs = [Job]()
        return client.get(url).map { response in
            guard let data = response.http.body.data else {
                return []
            }
            let cryptoJobs = try JSONDecoder().decode([CryptoJob].self, from: data)
            for cryptoJob in cryptoJobs {
                jobs.append(Job(cryptoJob))
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
