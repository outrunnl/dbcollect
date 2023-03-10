
class CustomException(Exception):
    pass

class ZipCreateError(CustomException):
    pass

class ReportingError(CustomException):
    pass

class TimeoutError(CustomException):
    pass

class InstanceDown(CustomException):
    pass
