// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DoctorRegistry {
    struct Doctor {
        string name;
        string specialization;
        string email;
        string username;
        bytes32 passwordHash; // Store hashed password
        string doctorId; // Unique doctor ID
        string licenseNumber;
        uint256 yearsOfExperience;
        string clinicName;
        string contactNumber;
        string addressDetails;
        bool isRegistered;
    }

    struct Patient {
        string name;
        string email;
        string username;
        string patientId;
        string contactNumber;
        string addressDetails;
        uint256 age;
        string gender;
        bool isRegistered;
    }

    struct Availability {
        string date; // Date in YYYY-MM-DD format
        string[] timeSlots; // List of available time slots
    }

    struct Appointment {
        address patient;
        address doctor;
        string date;
        string time;
        AppointmentStatus appointmentStatus;
        bool hasDiagnosis; // Flag for diagnosis & prescription
    }

    enum AppointmentMode { Virtual, WalkIn }
    enum AppointmentStatus { Pending, Completed, Cancelled }

    struct Booking {
        address patient;
        address doctor;
        string date;
        string time;
        bool isConfirmed;
        AppointmentMode appointmentMode;
        AppointmentStatus appointmentStatus;
        bool hasDiagnosis;  // Add this field to track if diagnosis is written
    }

    struct DiagnosisPrescription {
        string diagnosis;
        string prescription;
        bool isWritten;
    }


    address[] public tempResults;
    address[] public registeredDoctors;

    mapping(address => Doctor) public doctors;
    mapping(address => Patient) public patients;

    mapping(string => address) private usernameToAddress; // Maps username to doctor’s address
    mapping(string => address) private usernameToPatient;

    mapping(string => bool) private usernameExists;
    mapping(string => bool) private doctorIdExists; // To ensure unique Doctor ID
    mapping(string => bool) private patientIdExists;

    mapping(address => mapping(string => string[])) private doctorAvailability; // Doctor -> (Date -> Time Slots)
    mapping(address => bytes32) private passwordResetCodes; // Stores password reset codes
    //mapping(address => Appointment[]) private doctorAppointments;

    mapping(address => Booking[]) public patientBookings;
    mapping(address => Booking[]) public doctorAppointments;

    mapping(address => mapping(address => DiagnosisPrescription)) public diagnosisRecords;

    event AppointmentBooked(
        address indexed patient,
        address indexed doctor,
        string date,
        string time,
        AppointmentMode appointmentMode
    );

    event AppointmentAttended(
        address indexed patient,
        address indexed doctor,
        string date,
        string time,
        AppointmentMode appointmentMode
    );

    event DoctorRegistered(address indexed doctorAddress, string username);
    event PatientRegistered(address indexed patientAddress, string username);
    //event AppointmentBooked(address indexed patient, address indexed doctor, string date, string time, AppointmentMode appointmentMode);
    event TimeSlotRemoved(address indexed doctor, string date, string time);

    event AvailabilitySet(address indexed doctorAddress, string date, string[] timeSlots);
    event PasswordResetRequested(address indexed doctorAddress, bytes32 resetCode);
    event PasswordResetSuccessful(address indexed doctorAddress);

    event DiagnosisWritten(address indexed doctor, address indexed patient, string diagnosis, string prescription);

    function registerDoctor(
    address _doctorAddress,
    string memory _name,
    string memory _specialization,
    string memory _email,
    string memory _username,
    string memory _doctorId,
    string memory _licenseNumber,
    uint256 _yearsOfExperience,
    string memory _clinicName,
    string memory _contactNumber,
    string memory _addressDetails
) public {
    require(!doctors[_doctorAddress].isRegistered, "Doctor already registered");
    require(!usernameExists[_username], "Username already taken");
    require(!doctorIdExists[_doctorId], "Doctor ID already exists");

    doctors[_doctorAddress] = Doctor({
        name: _name,
        specialization: _specialization,
        email: _email,
        username: _username,
        passwordHash: 0, // No password is being set in this function
        doctorId: _doctorId,
        licenseNumber: _licenseNumber,
        yearsOfExperience: _yearsOfExperience,
        clinicName: _clinicName,
        contactNumber: _contactNumber,
        addressDetails: _addressDetails,
        isRegistered: true
    });

    usernameExists[_username] = true;
    doctorIdExists[_doctorId] = true;
    usernameToAddress[_username] = _doctorAddress;

    registeredDoctors.push(_doctorAddress);

    emit DoctorRegistered(_doctorAddress, _username);
}


    // Register a new patient
    function registerPatient(
        string memory _name,
        string memory _email,
        string memory _username,
        string memory _patientId,
        string memory _contactNumber,
        string memory _addressDetails,
        uint256 _age,
        string memory _gender
    ) public {
        require(!patients[msg.sender].isRegistered, "Patient already registered");
        require(!usernameExists[_username], "Username already taken");
        require(!patientIdExists[_patientId], "Patient ID already exists");

        patients[msg.sender] = Patient({
            name: _name,
            email: _email,
            username: _username,
            patientId: _patientId,
            contactNumber: _contactNumber,
            addressDetails: _addressDetails,
            age: _age,
            gender: _gender,
            isRegistered: true
        });

        usernameExists[_username] = true;
        patientIdExists[_patientId] = true;
        usernameToPatient[_username] = msg.sender;

        emit PatientRegistered(msg.sender, _username);
    }

    function login(string memory _username, string memory _password) public view returns (bool) {
        address doctorAddr = usernameToAddress[_username];
        require(doctorAddr != address(0), "Doctor not found");

        Doctor memory doc = doctors[doctorAddr];
        require(
            keccak256(abi.encodePacked(_password)) == doc.passwordHash,
            "Incorrect password"
        );

        return true;
    }

    // Forgot Password - Request Reset
    function requestPasswordReset() public {
        require(doctors[msg.sender].isRegistered, "Doctor not registered");
        bytes32 resetCode = keccak256(abi.encodePacked(msg.sender, block.timestamp));
        passwordResetCodes[msg.sender] = resetCode;
        emit PasswordResetRequested(msg.sender, resetCode);
    }

    // Reset Password using the reset code
    function resetPassword(bytes32 _resetCode, string memory _newPassword) public {
        require(doctors[msg.sender].isRegistered, "Doctor not registered");
        require(passwordResetCodes[msg.sender] == _resetCode, "Invalid reset code");

        doctors[msg.sender].passwordHash = keccak256(abi.encodePacked(_newPassword));
        delete passwordResetCodes[msg.sender];

        emit PasswordResetSuccessful(msg.sender);
    }

    // Set availability
    function setAvailability(string memory _date, string[] memory _timeSlots) public {
        require(doctors[msg.sender].isRegistered, "Only registered doctors can set availability");
        require(bytes(_date).length > 0, "Invalid date");
        require(_timeSlots.length > 0, "At least one time slot required");

        doctorAvailability[msg.sender][_date] = _timeSlots;
        emit AvailabilitySet(msg.sender, _date, _timeSlots);
    }

    // Get a doctor's availability
    function getAvailability(address _doctorAddress, string memory _date) public view returns (string[] memory) {
        require(doctors[_doctorAddress].isRegistered, "Doctor not registered");
        return doctorAvailability[_doctorAddress][_date];
    }

    // Get doctor details
    function getDoctorDetails(address _doctorAddress) public view returns (
        string memory, string memory, string memory, string memory,
        string memory, string memory, uint256, string memory, string memory,
        string memory
    ) {
        require(doctors[_doctorAddress].isRegistered, "Doctor not registered");
        Doctor memory doc = doctors[_doctorAddress];
        return (
            doc.name, doc.specialization, doc.email, doc.username,
            doc.doctorId, doc.licenseNumber, doc.yearsOfExperience, doc.clinicName,
            doc.contactNumber, doc.addressDetails
        );
    }

    // Get patient details
    function getPatientDetails(address _patientAddress) public view returns (
        string memory, string memory, string memory, string memory,
        string memory, uint256, string memory, string memory
    ) {
        require(patients[_patientAddress].isRegistered, "Patient not registered");
        Patient memory pat = patients[_patientAddress];
        return (
            pat.name, pat.email, pat.username, pat.patientId,
            pat.contactNumber, pat.age, pat.gender, pat.addressDetails
        );
    }

    // Check if doctor is registered
    function isDoctorRegistered(address _doctorAddress) public view returns (bool) {
        return doctors[_doctorAddress].isRegistered;
    }

    // Check if patient is registered
    function isPatientRegistered(address _patientAddress) public view returns (bool) {
        return patients[_patientAddress].isRegistered;
    }

    function findAvailableDoctors(
    string memory _specialization,
    string memory _date,
    string memory _time
) public view returns (address[] memory) {
    address[] memory availableDoctors = new address[](registeredDoctors.length);
    uint count = 0;

    for (uint i = 0; i < registeredDoctors.length; i++) {
        address doctorAddress = registeredDoctors[i];

        if (doctors[doctorAddress].isRegistered) {
            if (keccak256(abi.encodePacked(doctors[doctorAddress].specialization)) ==
                keccak256(abi.encodePacked(_specialization))) {

                string[] memory timeSlots = doctorAvailability[doctorAddress][_date];

                if (timeSlots.length > 0) {
                    for (uint j = 0; j < timeSlots.length; j++) {
                        if (keccak256(abi.encodePacked(timeSlots[j])) ==
                            keccak256(abi.encodePacked(_time))) {
                            availableDoctors[count] = doctorAddress;
                            count++;
                            break;
                        }
                    }
                }
            }
        }
    }

    // Resize the array to fit the actual number of results
    address[] memory results = new address[](count);
    for (uint k = 0; k < count; k++) {
        results[k] = availableDoctors[k];
    }

    return results;
}
  

    function resetTempResults() internal {
        while (tempResults.length > 0) {
            tempResults.pop();
        }
    }

    function bookAppointment(address _doctorAddress, string memory _date, string memory _time, AppointmentMode _appointmentMode) public {
        require(patients[msg.sender].isRegistered, "Only registered patients can book");
        
        Booking memory newBooking = Booking({
            patient: msg.sender,
            doctor: _doctorAddress,
            date: _date,
            time: _time,
            isConfirmed: false,
            appointmentMode: _appointmentMode,
            appointmentStatus: AppointmentStatus.Pending,
            hasDiagnosis: false
        });

        patientBookings[msg.sender].push(newBooking);
        doctorAppointments[_doctorAddress].push(newBooking);

        // Remove the booked time slot
        removeTimeSlot(_doctorAddress, _date, _time);

        emit AppointmentBooked(msg.sender, _doctorAddress, _date, _time, _appointmentMode);
    }

    function removeTimeSlot(address _doctorAddress, string memory _date, string memory _time) internal {
        require(doctors[_doctorAddress].isRegistered, "Doctor not registered");

        string[] storage timeSlots = doctorAvailability[_doctorAddress][_date];
        bool timeSlotFound = false;
        uint256 index = 0;

        for (uint i = 0; i < timeSlots.length; i++) {
            if (keccak256(abi.encodePacked(timeSlots[i])) == keccak256(abi.encodePacked(_time))) {
                timeSlotFound = true;
                index = i;
                break;
            }
        }

        require(timeSlotFound, "Time slot not found");

        // Remove the time slot by shifting elements left
        for (uint j = index; j < timeSlots.length - 1; j++) {
            timeSlots[j] = timeSlots[j + 1];
        }
        timeSlots.pop(); // Remove last element

        emit TimeSlotRemoved(_doctorAddress, _date, _time);
    }

    // Function to allow a doctor to view patient details for booked appointments
    function getDoctorAppointments() public view returns (
        string[] memory, string[] memory, string[] memory, string[] memory, string[] memory
    ) {
        require(doctors[msg.sender].isRegistered, "Only registered doctors can view appointments");

        uint256 totalAppointments = doctorAppointments[msg.sender].length;
        string[] memory names = new string[](totalAppointments);
        string[] memory emails = new string[](totalAppointments);
        string[] memory contactNumbers = new string[](totalAppointments);
        string[] memory addresses = new string[](totalAppointments);
        string[] memory appointmentDates = new string[](totalAppointments);

        for (uint i = 0; i < totalAppointments; i++) {
            address patientAddress = doctorAppointments[msg.sender][i].patient;
            Patient memory pat = patients[patientAddress];

            names[i] = pat.name;
            emails[i] = pat.email;
            contactNumbers[i] = pat.contactNumber;
            addresses[i] = pat.addressDetails;
            appointmentDates[i] = doctorAppointments[msg.sender][i].date;
        }

        return (names, emails, contactNumbers, addresses, appointmentDates);
    }

    // Function for patient to confirm attendance
    function attendAppointment(address _doctorAddress, string memory _date, string memory _time) public {
        require(patients[msg.sender].isRegistered, "Only registered patients can confirm attendance");

        Booking[] storage bookings = patientBookings[msg.sender];
        bool found = false;

        for (uint i = 0; i < bookings.length; i++) {
            if (
                bookings[i].doctor == _doctorAddress &&
                keccak256(abi.encodePacked(bookings[i].date)) == keccak256(abi.encodePacked(_date)) &&
                keccak256(abi.encodePacked(bookings[i].time)) == keccak256(abi.encodePacked(_time))
            ) {
                require(bookings[i].appointmentStatus == AppointmentStatus.Pending, "Appointment already attended or cancelled");
                
                // Update status to "Completed"
                bookings[i].appointmentStatus = AppointmentStatus.Completed;
                found = true;

                emit AppointmentAttended(msg.sender, _doctorAddress, _date, _time, bookings[i].appointmentMode);
                break;
            }
        }

        require(found, "Appointment not found or already attended");
    }

    // Function to get the appointment status
    function getAppointmentStatus(address _patientAddress, address _doctorAddress, string memory _date, string memory _time)
        public
        view
        returns (AppointmentStatus)
    {
        require(patients[_patientAddress].isRegistered, "Patient not registered");
        require(doctors[_doctorAddress].isRegistered, "Doctor not registered");

        Booking[] storage bookings = patientBookings[_patientAddress];

        for (uint i = 0; i < bookings.length; i++) {
            if (
                bookings[i].doctor == _doctorAddress &&
                keccak256(abi.encodePacked(bookings[i].date)) == keccak256(abi.encodePacked(_date)) &&
                keccak256(abi.encodePacked(bookings[i].time)) == keccak256(abi.encodePacked(_time))
            ) {
                return bookings[i].appointmentStatus;
            }
        }

        revert("Appointment not found");
    }

    function writeDiagnosisPrescription(
    address _patientAddress,
    string memory _diagnosis,
    string memory _prescription
) public {
    require(doctors[msg.sender].isRegistered, "Only registered doctors can write diagnosis");
    require(patients[_patientAddress].isRegistered, "Patient not registered");

    // Find the relevant appointment and ensure it is completed
    bool appointmentFound = false;
    for (uint i = 0; i < doctorAppointments[msg.sender].length; i++) {
        if (doctorAppointments[msg.sender][i].patient == _patientAddress && 
            doctorAppointments[msg.sender][i].appointmentStatus == AppointmentStatus.Completed) {
            
            // Ensure diagnosis & prescription is only written once
            require(!diagnosisRecords[msg.sender][_patientAddress].isWritten, "Diagnosis already written for this appointment");

            // Store diagnosis & prescription
            diagnosisRecords[msg.sender][_patientAddress] = DiagnosisPrescription({
                diagnosis: _diagnosis,
                prescription: _prescription,
                isWritten: true
            });

            // Mark the appointment as having a diagnosis
            doctorAppointments[msg.sender][i].hasDiagnosis = true;  // Set hasDiagnosis to true

            emit DiagnosisWritten(msg.sender, _patientAddress, _diagnosis, _prescription);
            appointmentFound = true;
            break;
        }
    }
    require(appointmentFound, "Appointment not found or not completed yet");
}

    // Function to retrieve diagnosis and prescription for a patient
    function getDiagnosisPrescription(address _doctorAddress, address _patientAddress) public view returns (string memory, string memory) {
        require(doctors[_doctorAddress].isRegistered, "Doctor not registered");
        require(patients[_patientAddress].isRegistered, "Patient not registered");

        DiagnosisPrescription memory record = diagnosisRecords[_doctorAddress][_patientAddress];
        require(record.isWritten, "No diagnosis or prescription found for this patient");

        return (record.diagnosis, record.prescription);
    }

}
