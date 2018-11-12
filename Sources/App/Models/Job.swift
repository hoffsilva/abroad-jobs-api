import Vapor

struct Job: Content {
    let jobTitle: String
    let companyLogoURL: String
    let companyName: String
    let jobDescription: String
    let applyURL: String
    let tags: [String]
    let source: String
    
    init(jobTitle: String, companyLogoURL: String, companyName: String, jobDescription: String, applyURL: String, tags: [String], source: String) {
        self.jobTitle = jobTitle
        self.companyLogoURL = companyLogoURL
        self.companyName = companyName
        self.jobDescription = jobDescription
        self.applyURL = applyURL
        self.tags = tags
        self.source = source
    }
    
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
