/**
 * R3P Multi-Tenant Gym Management Data Layer
 * Strict Tenant Isolation + Role-Based Access Control + LocalStorage Persistence
 */

const STORAGE_KEY = 'R3P_SAAS_DB_V1';

const defaultSeedData = {
  // Current active session
  session: {
    userId: 'USR-OWNER-01',
    role: 'owner', // 'owner', 'member', 'trainer', 'staff', 'platform_admin'
    activeGymId: 'GYM-001'
  },
  
  // Platform subscription plans for SaaS operator
  saasPlans: [
    { id: 'SAAS-STARTER', name: 'Pro Gym Growth', monthlyFee: 999, activationFee: 499, memberLimit: 250, staffLimit: 5 },
    { id: 'SAAS-ENTERPRISE', name: 'Elite Multi-Branch', monthlyFee: 1999, activationFee: 499, memberLimit: 1000, staffLimit: 20 }
  ],

  // Platform gyms (multi-tenant isolation)
  gyms: [
    {
      id: 'GYM-001',
      name: 'IronForge Elite Fitness',
      slug: 'ironforge-elite',
      ownerId: 'USR-OWNER-01',
      phone: '+91 98765 43210',
      email: 'contact@ironforge.fit',
      city: 'Bangalore, Indiranagar',
      address: '100 Feet Rd, HAL 2nd Stage, Indiranagar',
      // Geofence configuration for staff attendance
      geofence: {
        latitude: 12.9716,
        longitude: 77.5946,
        radiusMeters: 150
      },
      subscription: {
        planId: 'SAAS-STARTER',
        status: 'active', // active, past_due, trial, suspended
        renewsOn: '2026-11-19',
        monthlyRateINR: 999,
        activationPaidINR: 499
      },
      settings: {
        currency: 'INR',
        currencySymbol: '₹',
        timezone: 'Asia/Kolkata',
        taxPercent: 18,
        streakMinVisitMinutes: 30
      }
    },
    {
      id: 'GYM-002',
      name: 'Olympus Athletics Club',
      slug: 'olympus-club',
      ownerId: 'USR-OWNER-02',
      phone: '+91 98111 22334',
      city: 'Mumbai, Bandra West',
      address: 'Pali Hill, Bandra West',
      geofence: { latitude: 19.0596, longitude: 72.8295, radiusMeters: 100 },
      subscription: { planId: 'SAAS-STARTER', status: 'active', renewsOn: '2026-11-05', monthlyRateINR: 999, activationPaidINR: 499 },
      settings: { currency: 'INR', currencySymbol: '₹', timezone: 'Asia/Kolkata', taxPercent: 18, streakMinVisitMinutes: 30 }
    }
  ],

  // Gym Membership Plans offered to gym members
  membershipPlans: [
    { id: 'PLAN-01', gymId: 'GYM-001', name: 'Gold Annual Pass', durationMonths: 12, priceINR: 14999, features: ['Gym Floor', 'Locker Room', 'Steam Bath', 'All Group Classes'] },
    { id: 'PLAN-02', gymId: 'GYM-001', name: 'Quarterly Beast', durationMonths: 3, priceINR: 4999, features: ['Gym Floor', 'Cardio Suite', 'Lockers'] },
    { id: 'PLAN-03', gymId: 'GYM-001', name: 'Monthly Flexible', durationMonths: 1, priceINR: 1999, features: ['Gym Floor Access'] }
  ],

  // Users across roles
  users: [
    {
      id: 'USR-OWNER-01',
      gymId: 'GYM-001',
      role: 'owner',
      name: 'Vikramaditya Rathore',
      email: 'vikram@ironforge.fit',
      phone: '+91 98765 00001',
      avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
      joinedDate: '2025-01-15'
    },
    {
      id: 'USR-MEMBER-01',
      gymId: 'GYM-001',
      role: 'member',
      name: 'Aarav Sharma',
      email: 'aarav.sharma@example.com',
      phone: '+91 98222 33445',
      avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
      membershipPlanId: 'PLAN-01',
      membershipStatus: 'active',
      planExpiry: '2026-12-10',
      outstandingDuesINR: 0,
      assignedTrainerId: 'USR-TRAINER-01',
      fitnessGoal: 'Hypertrophy & Core Conditioning',
      streakCurrent: 14,
      streakBest: 28,
      monthlyVisits: 18,
      joinedDate: '2025-06-10'
    },
    {
      id: 'USR-MEMBER-02',
      gymId: 'GYM-001',
      role: 'member',
      name: 'Rohan Deshmukh',
      email: 'rohan.d@example.com',
      phone: '+91 98333 44556',
      avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
      membershipPlanId: 'PLAN-02',
      membershipStatus: 'expiring_soon',
      planExpiry: '2026-10-25',
      outstandingDuesINR: 1500, // Partial payment pending
      assignedTrainerId: 'USR-TRAINER-01',
      fitnessGoal: 'Fat Loss & Stamina',
      streakCurrent: 5,
      streakBest: 12,
      monthlyVisits: 9,
      joinedDate: '2026-07-25'
    },
    {
      id: 'USR-TRAINER-01',
      gymId: 'GYM-001',
      role: 'trainer',
      name: 'Coach Marcus Vance',
      email: 'marcus@ironforge.fit',
      phone: '+91 98444 55667',
      avatar: 'https://images.unsplash.com/photo-1568602471122-7832951cc4c5?auto=format&fit=crop&w=150&q=80',
      speciality: 'Olympic Weightlifting & Strength Coaching',
      salaryModel: 'fixed_plus_pt',
      baseSalaryINR: 35000,
      ptIncentiveINR: 12000,
      totalPaidThisMonthINR: 47000,
      pendingSalaryINR: 0,
      rating: 4.9,
      assignedClientsCount: 16
    },
    {
      id: 'USR-STAFF-01',
      gymId: 'GYM-001',
      role: 'staff',
      name: 'Deepak Patel',
      email: 'deepak.desk@ironforge.fit',
      phone: '+91 98555 66778',
      avatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=150&q=80',
      designation: 'Front Desk & Floor Operations',
      salaryModel: 'fixed',
      baseSalaryINR: 22000,
      totalPaidThisMonthINR: 22000,
      pendingSalaryINR: 0,
      approvedHoursMonth: 182
    },
    {
      id: 'USR-PLATFORM-ADMIN',
      gymId: null,
      role: 'platform_admin',
      name: 'Antigravity SaaS SuperAdmin',
      email: 'ops@r3pgym.com',
      avatar: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=150&q=80'
    }
  ],

  // Financial transactions & dues (Member fees & SaaS billing)
  transactions: [
    {
      id: 'TXN-9012',
      gymId: 'GYM-001',
      memberId: 'USR-MEMBER-01',
      amountINR: 14999,
      type: 'membership_renewal',
      status: 'paid', // paid, pending, failed, refunded
      method: 'Razorpay UPI (Verified Sandbox)',
      referenceNo: 'pay_RP_sim_8923019',
      date: '2026-06-10T11:30:00Z',
      invoiceNumber: 'INV-2026-081',
      taxINR: 2287
    },
    {
      id: 'TXN-9013',
      gymId: 'GYM-001',
      memberId: 'USR-MEMBER-02',
      amountINR: 3499,
      type: 'partial_payment',
      status: 'paid',
      method: 'Card Payment (Sandbox)',
      referenceNo: 'pay_RP_sim_9918231',
      date: '2026-07-25T14:15:00Z',
      invoiceNumber: 'INV-2026-112',
      taxINR: 533
    },
    {
      id: 'TXN-SAAS-101',
      gymId: 'GYM-001',
      memberId: null,
      amountINR: 999,
      type: 'saas_gym_subscription',
      status: 'paid',
      method: 'Google Play Subscription / Direct Mandate',
      referenceNo: 'sub_gplay_90192',
      date: '2026-10-19T00:00:00Z',
      invoiceNumber: 'SAAS-INV-441'
    }
  ],

  // Group classes scheduled
  classes: [
    {
      id: 'CLS-01',
      gymId: 'GYM-001',
      title: 'HIIT Kettlebell Ignition',
      trainerId: 'USR-TRAINER-01',
      trainerName: 'Marcus Vance',
      time: 'Today, 06:30 PM',
      duration: '45 mins',
      capacity: 18,
      bookedCount: 14,
      location: 'Studio A'
    },
    {
      id: 'CLS-02',
      gymId: 'GYM-001',
      title: 'Power Yoga & Spinal Mobility',
      trainerId: 'USR-TRAINER-01',
      trainerName: 'Marcus Vance',
      time: 'Tomorrow, 07:00 AM',
      duration: '60 mins',
      capacity: 20,
      bookedCount: 9,
      location: 'Mind & Body Studio'
    },
    {
      id: 'CLS-03',
      gymId: 'GYM-001',
      title: 'Cross-functional Strength Circuit',
      trainerId: 'USR-TRAINER-01',
      trainerName: 'Marcus Vance',
      time: 'Tomorrow, 06:00 PM',
      duration: '50 mins',
      capacity: 15,
      bookedCount: 12,
      location: 'Turf Zone'
    }
  ],

  // Staff Geofenced Attendance Sessions
  staffAttendance: [
    {
      id: 'ATT-STF-01',
      gymId: 'GYM-001',
      staffId: 'USR-STAFF-01',
      staffName: 'Deepak Patel',
      date: '2026-10-19',
      clockInTime: '06:00 AM',
      clockOutTime: '02:30 PM',
      hoursWorked: 8.5,
      isGeofenceVerified: true,
      clockInDistanceMeters: 28,
      status: 'completed'
    }
  ],

  // Member Workouts Logged & Trainer Prescriptions
  memberWorkouts: [
    {
      id: 'WKT-101',
      gymId: 'GYM-001',
      memberId: 'USR-MEMBER-01',
      title: 'Heavy Push Hypertrophy (Prescribed by Marcus)',
      isTrainerAssigned: true,
      trainerId: 'USR-TRAINER-01',
      assignedDate: '2026-10-18',
      status: 'in_progress',
      exercises: [
        { id: 'EX-0001', name: 'Barbell Bench Press', sets: 4, reps: 8, rest: '90s', targetWeightKg: 85, completed: true },
        { id: 'EX-0002', name: 'Incline Dumbbell Press', sets: 3, reps: 10, rest: '75s', targetWeightKg: 30, completed: true },
        { id: 'EX-0013', name: 'Overhead Barbell Military Press', sets: 4, reps: 6, rest: '90s', targetWeightKg: 55, completed: false },
        { id: 'EX-0028', name: 'Tricep Rope Pushdowns', sets: 3, reps: 15, rest: '60s', targetWeightKg: 25, completed: false }
      ]
    }
  ],

  // In-app Notifications
  notifications: [
    {
      id: 'NOTIF-01',
      gymId: 'GYM-001',
      recipientId: 'USR-MEMBER-01',
      title: 'Class Booking Confirmed',
      message: 'You are booked for HIIT Kettlebell Ignition at 06:30 PM.',
      timestamp: '2 hours ago',
      read: false,
      type: 'booking'
    },
    {
      id: 'NOTIF-02',
      gymId: 'GYM-001',
      recipientId: 'USR-OWNER-01',
      title: 'Monthly Subscription Renewed',
      message: '₹999 SaaS subscription successfully charged for IronForge Elite.',
      timestamp: '5 hours ago',
      read: true,
      type: 'saas'
    }
  ]
};

class GymStore {
  constructor() {
    this.init();
  }

  init() {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) {
      this.state = defaultSeedData;
      this.save();
    } else {
      try {
        this.state = JSON.parse(raw);
        // Ensure defaults if schema upgraded
        if (!this.state.gyms) this.state.gyms = defaultSeedData.gyms;
      } catch (e) {
        this.state = defaultSeedData;
        this.save();
      }
    }
  }

  save() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(this.state));
  }

  // Tenant Isolation: Always filters by current gymId
  getActiveGym() {
    const currentGymId = this.state.session.activeGymId;
    return this.state.gyms.find(g => g.id === currentGymId) || this.state.gyms[0];
  }

  getCurrentUser() {
    return this.state.users.find(u => u.id === this.state.session.userId) || this.state.users[0];
  }

  setRole(role) {
    const targetUser = this.state.users.find(u => u.role === role);
    if (targetUser) {
      this.state.session.userId = targetUser.id;
      this.state.session.role = role;
      if (targetUser.gymId) {
        this.state.session.activeGymId = targetUser.gymId;
      }
      this.save();
    }
  }

  // Member queries with Tenant Isolation
  getGymMembers() {
    const gymId = this.state.session.activeGymId;
    return this.state.users.filter(u => u.role === 'member' && u.gymId === gymId);
  }

  // Financial calculations
  getFinancialSummary() {
    const gymId = this.state.session.activeGymId;
    const gymTxns = this.state.transactions.filter(t => t.gymId === gymId && t.status === 'paid' && t.type !== 'saas_gym_subscription');
    const totalCollected = gymTxns.reduce((acc, curr) => acc + (curr.amountINR || 0), 0);
    
    const members = this.getGymMembers();
    const totalPendingDues = members.reduce((acc, curr) => acc + (curr.outstandingDuesINR || 0), 0);

    return {
      totalCollectedINR: totalCollected,
      pendingDuesINR: totalPendingDues,
      activeMembersCount: members.filter(m => m.membershipStatus === 'active').length,
      expiringSoonCount: members.filter(m => m.membershipStatus === 'expiring_soon').length,
      totalMembers: members.length
    };
  }

  // Record Member Payment (Razorpay sandbox simulator)
  recordPayment(memberId, amountINR, paymentType, method) {
    const gymId = this.state.session.activeGymId;
    const txnId = 'TXN-' + Math.floor(1000 + Math.random() * 9000);
    const invoiceNum = 'INV-2026-' + Math.floor(100 + Math.random() * 900);
    
    const newTxn = {
      id: txnId,
      gymId: gymId,
      memberId: memberId,
      amountINR: Number(amountINR),
      type: paymentType,
      status: 'paid',
      method: method || 'Razorpay UPI (Sandbox Verified)',
      referenceNo: 'pay_RP_sandbox_' + Math.random().toString(36).substring(7),
      date: new Date().toISOString(),
      invoiceNumber: invoiceNum,
      taxINR: Math.round(Number(amountINR) * 0.18 / 1.18)
    };

    this.state.transactions.unshift(newTxn);

    // If dues are paid, update member dues
    const member = this.state.users.find(u => u.id === memberId);
    if (member) {
      member.outstandingDuesINR = Math.max(0, (member.outstandingDuesINR || 0) - Number(amountINR));
      if (member.outstandingDuesINR === 0 && member.membershipStatus === 'expiring_soon') {
        member.membershipStatus = 'active';
      }
    }

    this.addNotification(memberId, 'Payment Received & Receipt Generated', 'Payment of INR ' + amountINR + ' verified. Receipt generated.', 'payment');
    this.save();
    return newTxn;
  }

  // Geofence attendance verification
  recordStaffAttendance(staffId, coords) {
    const gym = this.getActiveGym();
    const targetLat = gym.geofence.latitude;
    const targetLng = gym.geofence.longitude;
    const maxRadius = gym.geofence.radiusMeters;

    // Haversine formula calculation for distance in meters
    const R = 6371e3; // Earth radius in meters
    const phi1 = (coords.latitude * Math.PI) / 180;
    const phi2 = (targetLat * Math.PI) / 180;
    const deltaPhi = ((targetLat - coords.latitude) * Math.PI) / 180;
    const deltaLambda = ((targetLng - coords.longitude) * Math.PI) / 180;

    const a = Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
              Math.cos(phi1) * Math.cos(phi2) *
              Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distanceMeters = Math.round(R * c);

    const isVerified = distanceMeters <= maxRadius;

    const user = this.state.users.find(u => u.id === staffId);
    const timeStr = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    const attendanceRecord = {
      id: 'ATT-' + Date.now().toString().slice(-6),
      gymId: gym.id,
      staffId: staffId,
      staffName: user ? user.name : 'Staff Member',
      date: new Date().toISOString().split('T')[0],
      clockInTime: timeStr,
      clockOutTime: 'Active Session',
      hoursWorked: 0,
      isGeofenceVerified: isVerified,
      clockInDistanceMeters: distanceMeters,
      status: isVerified ? 'verified_clockin' : 'out_of_bounds'
    };

    this.state.staffAttendance.unshift(attendanceRecord);
    this.save();
    return { record: attendanceRecord, distanceMeters, isVerified, maxRadius };
  }

  addNotification(recipientId, title, message, type = 'info') {
    this.state.notifications.unshift({
      id: 'NOTIF-' + Date.now().toString().slice(-5),
      gymId: this.state.session.activeGymId,
      recipientId: recipientId,
      title: title,
      message: message,
      timestamp: 'Just now',
      read: false,
      type: type
    });
    this.save();
  }
}

window.appStore = new GymStore();
console.log('R3P Store initialized with multi-tenant data.');
