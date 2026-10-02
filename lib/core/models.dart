int? asInt(dynamic v) => v == null ? null : (v as num).toInt();
double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();

const labourTypes = ['PLUMBER', 'ELECTRICIAN', 'CARPENTER', 'PAINTER', 'MASON', 'HELPER', 'CLEANER'];
const employmentTypes = ['ONE_TIME', 'PART_TIME', 'FULL_TIME'];

class Job {
  final int id, customerId;
  final int? acceptedLabourId;
  final String title, labourType, status;
  final String? description, address, skills;
  final double? budget;
  final double latitude, longitude;

  Job.fromJson(Map<String, dynamic> j)
      : id = asInt(j['id'])!,
        customerId = asInt(j['customerId'])!,
        acceptedLabourId = asInt(j['acceptedLabourId']),
        title = j['title'] ?? '',
        labourType = j['requiredLabourType'] ?? '',
        status = j['status'] ?? 'OPEN',
        description = j['description'],
        address = j['addressText'],
        skills = j['skillsRequiredCsv'],
        budget = asDouble(j['budget']),
        latitude = asDouble(j['latitude']) ?? 0,
        longitude = asDouble(j['longitude']) ?? 0;

  bool get isOpen => status == 'OPEN';
  bool get isAccepted => acceptedLabourId != null;
}
