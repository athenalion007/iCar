import Foundation

extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    var isValidPhoneNumber: Bool {
        let phoneRegex = "^1[3-9]\\d{9}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }
    
    var isValidLicensePlate: Bool {
        let plateRegex = "^[京津沪渝冀豫云辽黑湘皖鲁新苏浙赣鄂桂甘晋蒙陕吉闽贵粤青藏川宁琼使领][A-Z][A-Z0-9]{4,5}[A-Z0-9挂学警港澳]?$"
        let platePredicate = NSPredicate(format: "SELF MATCHES %@", plateRegex)
        return platePredicate.evaluate(with: self)
    }
    
    var isValidVIN: Bool {
        let vinRegex = "^[A-HJ-NPR-Z0-9]{17}$"
        let vinPredicate = NSPredicate(format: "SELF MATCHES %@", vinRegex)
        return vinPredicate.evaluate(with: self)
    }
    
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isNotEmpty: Bool {
        !self.trimmed.isEmpty
    }
    
    static func formatDate(_ date: Date, format: String = "yyyy-MM-dd HH:mm") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    func toDate(format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale.current
        return formatter.date(from: self)
    }
    
    func toInt() -> Int? {
        Int(self)
    }
    
    func toDouble() -> Double? {
        Double(self)
    }
    
    func localized() -> String {
        NSLocalizedString(self, comment: "")
    }
    
    func maskedPhoneNumber() -> String {
        guard self.count == 11 else { return self }
        let start = self.prefix(3)
        let end = self.suffix(4)
        return "\(start)****\(end)"
    }
    
    func maskedEmail() -> String {
        guard self.contains("@") else { return self }
        let components = self.split(separator: "@")
        guard components.count == 2 else { return self }
        let localPart = String(components[0])
        let domain = String(components[1])
        
        if localPart.count <= 2 {
            return self
        }
        
        let firstChar = localPart.prefix(1)
        let lastChar = localPart.suffix(1)
        return "\(firstChar)***\(lastChar)@\(domain)"
    }
}
