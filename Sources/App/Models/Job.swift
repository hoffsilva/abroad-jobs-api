import Vapor

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
        self.jobTitle = landingJob.jobTitle
        self.companyLogoURL = landingJob.companyLogoURL
        self.companyName = landingJob.companyName
        self.jobDescription = ""
        self.applyURL = landingJob.applyURL
        self.tags = landingJob.skills.map { $0.name }
        self.source = "landing-jobs"
    }
    
    init(_ cryptoJob: CryptoJob) {
        self.jobTitle = cryptoJob.jobTitle
        self.companyLogoURL = cryptoJob.companyLogoURL ?? "NA"
        self.companyName = cryptoJob.companyName
        self.jobDescription = cryptoJob.jobDescription
        self.applyURL = cryptoJob.applyURL
        self.tags = [cryptoJob.category ?? ""].filter { $0 != "" }
        self.source = "cryptojobslist"
    }
    
    init(_ vanhackJob: VanhackJob) {
        self.jobTitle = vanhackJob.positionName
        self.companyLogoURL = vanhackJob.company ?? "NA"
        self.companyName = vanhackJob.company ?? "NA"
        self.jobDescription = vanhackJob.description
        self.applyURL = "https://app.vanhack.com/JobBoard/JobDetails?idJob=" + String(vanhackJob.id)
        self.tags = [vanhackJob.mustHaveSkills].map { $0.map { $0.name } }.first ?? [""]
        self.source = "vanhackjobs"
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


//Vanhack Jobs

struct VanhackResult: Decodable {
    let totalQuery: Int
    let totalCount: Int
    let items: [VanhackJob]
}

struct VanhackJob: Decodable {
    let positionName: String
    let description: String
    let company: String?
    let city: String
    let country: String
    let postDate: String
    let mustHaveSkills: [Skill]
    let jobType: String
    let salaryRangeStart: String?
    let salaryRangeEnd: String?
    let applied: Bool
    let favorited: Bool
    let newJob: Bool
    let matchPorcentage: Int
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



