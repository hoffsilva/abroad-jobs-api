import Foundation
import SwiftSoup
import Vapor

final class Parser {
    let client: Client
    var currentPageRemotelyAwesome = 1

    init(client: Client) {
        self.client = client
    }

    public func getJobs(_ worker: Worker) throws -> Future<[[Job]]> {
        var futureJobs: [Future<[Job]>] = []
        futureJobs.append(try getJobsFromRemoteOK(on: worker))
        futureJobs.append(try getJobsFromLandingJobs(on: worker))
        futureJobs.append(try getJobsFromCryptoJobs(on: worker))
        futureJobs.append(try getJobsFromVanhack(on: worker))
        // for _ in 1 ... 57 {
        //     futureJobs.append(try getJobsRemotelyAwesome(on: worker))
        //     currentPageRemotelyAwesome += 1
        // }
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
                guard arrayData.count >= 3 else {
                    continue
                }
                let jobTitle = try arrayData[1].select("a h2").text()
                let companyLogoURL = try arrayData[0].select("div").attr("data-original")
                let companyName = try arrayData[1].select("a h3").text()
                let applyURL = try "https://remoteok.io" + arrayData[1].select("a").attr("href")
                let tags = try arrayData[3].select("h3").array().map { try $0.text() }
                var jobDescription = try trDescription?.text().components(separatedBy: " See more jobs at").first ?? ""
                jobDescription = jobDescription.replacingOccurrences(of: "{linebreak}", with: "\n")
                let job = Job(jobTitle: jobTitle, companyLogoURL: companyLogoURL, companyName: companyName, jobDescription: jobDescription, applyURL: applyURL, tags: tags, source: Constants.remoteOkSource)
                jobs.append(job)
            }
            return jobs
        }
    }

    private func getJobsRemotelyAwesome(on _: Worker) throws -> Future<[Job]> {
        guard let url = URL(string: Constants.remotelyAwesomeJobsURL + String(currentPageRemotelyAwesome)) else {
            throw Abort(.internalServerError)
        }
        return client.get(url).map { response in
            let html = response.http.body.description
            let document = try SwiftSoup.parse(html)
            let htmlJobsList = try document.select("div.jobs-container li").array()
            var jobs = [Job]()
            for htmlJob in htmlJobsList {
                let jobTitle = try htmlJob.select("h2 a").text()
                let companyName = try htmlJob.select("h2 span span").text()
                let applyURL = try Constants.remotelyAwesomeJobDetailURL + htmlJob.select("h2 a").attr("href")
                let tags = try htmlJob.select("meta").array()[1].attr("content").components(separatedBy: ",")
                let jobDescription = ""
                let job = Job(jobTitle: jobTitle, companyLogoURL: "", companyName: companyName, jobDescription: jobDescription, applyURL: applyURL, tags: tags, source: Constants.remotelyAwesomeJobsSource)
                jobs.append(job)
            }
            return jobs
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
