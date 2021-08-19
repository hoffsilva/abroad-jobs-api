import Vapor

enum Constants {
    // Source
    static let remoteOkSource = "remote-ok"
    static let landingJobsSource = "landing-jobs"
    static let cryptoJobsSource = "cryptojobslist"
    static let vanhackJobsSource = "vanhackjobs"
    static let iosDevJobs = "iOSDevJobs"
    // Urls
    static let remoteOkURL = "https://remoteok.io/remote-jobs"
    static let cryptoJobsURL = "https://cryptojobslist.com"
    static let vanhackJobsURL = "https://api-vanhack-prod.azurewebsites.net/v1/job/search/full/?remotejob=&internal=&countries=&experiencelevels=&MaxResultCount=1000"
    static let landingJobsURL = "https://landing.jobs/jobs/search.json"
    static let landingJobsSearchURL = "https://landing.jobs/jobs/search.json?page="
    static let iosDevJobsURL = "https://iosdevjobs.com"
}

struct Job: Content {
    let jobTitle: String
    let companyLogoURL: String
    let companyName: String
    let jobDescription: String
    let applyURL: String
    let tags: [String]
    let source: String
}

extension Job {
    init(_ landingJob: LandingJob) {
        jobTitle = landingJob.jobTitle
        companyLogoURL = landingJob.companyLogoURL
        companyName = landingJob.companyName
        jobDescription = ""
        applyURL = landingJob.applyURL
        tags = landingJob.skills.map { $0.name }
        source = Constants.landingJobsSource
    }

    init(_ cryptoJob: CryptoJob) {
        jobTitle = cryptoJob.jobTitle
        companyLogoURL = cryptoJob.companyLogoURL ?? "NA"
        companyName = cryptoJob.companyName
        jobDescription = cryptoJob.jobDescription
        applyURL = cryptoJob.applyURL
        tags = [cryptoJob.category ?? ""].filter { $0 != "" }
        source = Constants.cryptoJobsSource
    }

    init(_ vanhackJob: VanhackJob) {
        jobTitle = vanhackJob.positionName
        companyLogoURL = vanhackJob.company ?? "NA"
        companyName = vanhackJob.company ?? "NA"
        jobDescription = vanhackJob.description
        applyURL = "https://app.vanhack.com/JobBoard/JobDetails?idJob=" + String(vanhackJob.id)
        if let skills = vanhackJob.mustHaveSkills {
            tags = [skills].map { $0.map { $0.name } }.first ?? [""]
        } else {
            tags = [""]
        }
        source = Constants.vanhackJobsSource
    }

}

struct LandingJob: Decodable {
    struct Skill: Decodable {
        let name: String
    }

    enum CodingKeys: String, CodingKey {
        case jobTitle = "title"
        case companyLogoURL = "company_logo_url"
        case companyName = "company_name"
        case applyURL = "url"
        case skills
    }

    let jobTitle: String
    let companyLogoURL: String
    let companyName: String
    let applyURL: String
    let skills: [Skill]
}

struct LandingJobsData: Decodable {
    enum CodingKeys: String, CodingKey {
        case isLastPage = "last_page?"
        case criteria
        case offers
    }

    let isLastPage: Bool
    let criteria: String
    let offers: [LandingJob]

    var numberOfPages: Int {
        guard let totalJobs = Int32(criteria.split(separator: " ").first ?? "") else {
            return 0
        }
        let pages = div(totalJobs, 50)
        return Int(pages.quot + (pages.rem > 0 ? 1 : 0))
    }
}

struct CryptoJob: Decodable {
    enum CodingKeys: String, CodingKey {
        case jobTitle
        case companyLogoURL = "companyLogo"
        case companyName
        case jobDescription
        case applyURL = "canonicalURL"
        case category
    }

    let jobTitle: String
    let companyLogoURL: String?
    let companyName: String
    let jobDescription: String
    let applyURL: String
    let category: String?
}

// Vanhack Jobs

struct VanhackResult: Decodable {
    let totalQuery: Int
    let totalCount: Int
    let items: [VanhackJob]
}

struct VanhackJob: Decodable {
    let positionName: String
    let description: String
    let company: String?
    let city: String?
    let country: String
    let postDate: String
    let mustHaveSkills: [Skill]?
    let niceToHaveSkills: [Skill]?
    let jobType: String
    let salaryRangeStart: Int?
    let salaryRangeEnd: Int?
    let applied: Bool
    let favorited: Bool
    let newJob: Bool
    let matchPorcentage: Int?
    let id: Int
}

struct Skill: Decodable {
    let id: Int
    let name: String
    let match: Bool
}

struct ResultOfVanhack: Decodable {
    let result: VanhackResult
    let targetUrl: String?
    let success: Bool
    let error: String?
    let unAuthorizedRequest: Bool
    let abp: Bool
    enum CodingKeys: String, CodingKey {
        case abp = "__abp"
        case result
        case targetUrl
        case success
        case error
        case unAuthorizedRequest
    }
}

// iOSDevJobs

struct ResultOfiOSDevJobs: Decodable {
    let found_jobs: Bool
    let showing: String
    let max_num_pages: Int
    let showing_links: String
    let html: String
}
