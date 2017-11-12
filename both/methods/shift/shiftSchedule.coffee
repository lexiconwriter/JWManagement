Meteor.methods

	cancelTeam: (shiftId, teamId, message) ->
		shift = Shifts.findOne shiftId, fields: teams: 1, tagId: 1, projectId: 1, start: 1, end: 1, date: 1

		if Meteor.isServer
			check { shiftId: shiftId, teamId: teamId }, isExistingShiftAndTeam
			check { projectId: shift.projectId, userId: Meteor.userId() }, isMember
			if message?
				check message, String

			for team in shift.teams when team._id == teamId
				if message == 'missingParticipant'
					for pendingUser in team.pending
						pendingUser.checked = false
						pendingUser.informed = false

						Shifts.update _id: shiftId, 'teams._id': teamId,
							$pull: 'teams.$.pending': _id: pendingUser._id
							$addToSet: 'teams.$.declined': pendingUser

					for participant in team.participants
						participant.checked = true
						participant.informed = false

						Shifts.update _id: shiftId, 'teams._id': teamId,
							$pull: 'teams.$.participants': _id: participant._id
							$addToSet: 'teams.$.pending': participant

					Meteor.call 'openTeam', shiftId, teamId

				else
					for participant in team.participants.concat(team.pending)
						participant.thisTeamleader = false

						Shifts.update _id: shiftId, 'teams._id': teamId,
							$pull: 'teams.$.declined': _id: participant._id

						Shifts.update _id: shiftId, 'teams._id': teamId,
							$pull: 'teams.$.pending': _id: participant._id

						Shifts.update _id: shiftId, 'teams._id': teamId,
							$pull: 'teams.$.participants': _id: participant._id
							$addToSet: 'teams.$.declined': participant

					Meteor.call 'openTeam', shiftId, teamId

				Meteor.call 'sendCancelTeam', shiftId, teamId, message

	approveRequest: (shiftId, teamId, userId) ->
		shift = Shifts.findOne shiftId, fields: teams: 1, tagId: 1, projectId: 1
		user = Meteor.users.findOne userId, fields: _id: 1

		if Meteor.isClient
			Meteor.subscribe 'userStatistics', userId, shiftId

		if Meteor.isServer
			check userId, isExistingUser
			check { shiftId: shiftId, teamId: teamId }, isExistingShiftAndTeam
			check { projectId: shift.projectId, userId: Meteor.userId() }, isShiftScheduler
			check { tagId: shift.tagId, userId: userId }, isTagParticipant

			for team in shift.teams
				if team._id == teamId
					hasTeamleader = false
					isTeamleader = false

					for participant in team.participants
						if participant.thisTeamleader
							hasTeamleader = true
						if participant._id == userId
							isTeamleader = (participant.teamleader || participant.substituteTeamleader)

					for approvedUser in team.pending.concat(team.declined) when approvedUser._id == userId
						approvedUser.thisTeamleader = (!hasTeamleader && isTeamleader)
						approvedUser.checked = false

						Shifts.update _id: shiftId, 'teams._id': teamId,
							$pull:
								'teams.$.pending': _id: userId
								'teams.$.declined': _id: userId
							$addToSet: 'teams.$.participants': approvedUser
						break

					if team.participants.length == team.max - 1
						Meteor.call 'closeTeam', shiftId, teamId
				else
					for user in team.participants when user._id == userId
						wholeTeamCancelled = false

						if user.thisTeamleader
							foundTeamleader = false

							for participant in team.participants when participant.teamleader
								foundTeamleader = true
								Meteor.call 'setLeader', shiftId, team._id, participant._id
								break

							if !foundTeamleader
								for participant in team.participants when participant.substituteTeamleader
									foundTeamleader = true
									Meteor.call 'setLeader', shiftId, team._id, participant._id
									break

							if !foundTeamleader
								wholeTeamCancelled = true
								Meteor.call 'cancelTeam', shiftId, team._id

						if !wholeTeamCancelled
							user.thisTeamleader = false

							Shifts.update _id: shiftId, 'teams._id': team._id,
								$pull: 'teams.$.participants': _id: userId
								$addToSet: 'teams.$.declined': user
						break

	declineRequest: (shiftId, teamId, userId) ->
		shift = Shifts.findOne shiftId, fields: teams: 1

		if Meteor.isClient
			Meteor.subscribe 'userStatistics', userId, shiftId

		if Meteor.isServer
			check { shiftId: shiftId, teamId: teamId }, isExistingShiftAndTeam

			for team in shift.teams when team._id == teamId
				for pending in team.pending when pending._id == userId
					user = pending

			Shifts.update _id: shiftId, 'teams._id': teamId,
				$pull: 'teams.$.pending': _id: userId
				$addToSet: 'teams.$.declined': user

	declineParticipant: (shiftId, teamId, userId) ->
		shift = Shifts.findOne shiftId, fields: teams: 1, tagId: 1, projectId: 1
		user = Meteor.users.findOne userId, fields: _id: 1

		if Meteor.isClient
			Meteor.subscribe 'userStatistics', userId, shiftId

		if Meteor.isServer
			check userId, isExistingUser
			check { shiftId: shiftId, teamId: teamId }, isExistingShiftAndTeam
			check { tagId: shift.tagId, userId: userId }, isTagParticipant

			for team in shift.teams when team._id == teamId
				if team.participants.length == team.min
					Meteor.call 'cancelTeam', shiftId, teamId, 'missingParticipant'
				else
					wasTeamleader = false
					hasTeamleader = false
					participantData = {}
					newTeamleaderData = {}

					for participant in team.participants
						if participant._id == userId
							participantData = participant

							if participant.thisTeamleader
								wasTeamleader = true
								participantData.thisTeamleader = false
						else if participant.teamleader || participant.substituteTeamleader
							hasTeamleader = true
							newTeamleaderData = participant
							newTeamleaderData.thisTeamleader = true

					if wasTeamleader
						if hasTeamleader
							Shifts.update _id: shiftId, 'teams._id': teamId,
								$pull: 'teams.$.participants': _id: userId

							Shifts.update _id: shiftId, 'teams._id': teamId,
								$pull: 'teams.$.participants': _id: newTeamleaderData._id

							Shifts.update _id: shiftId, 'teams._id': teamId,
								$addToSet:
									'teams.$.declined': participantData
									'teams.$.participants': newTeamleaderData
						else
							Meteor.call 'cancelTeam', shiftId, teamId
					else
						Shifts.update _id: shiftId, 'teams._id': teamId,
							$pull: 'teams.$.participants': _id: userId
							$addToSet: 'teams.$.declined': participantData

					if participantData.informed and userId != Meteor.userId()
						Meteor.call 'sendReversal', shiftId, teamId, userId

					Meteor.call 'openTeam', shiftId, teamId

	setLeader: (shiftId, teamId, userId) ->
		shift = Shifts.findOne shiftId, fields: teams: 1, tagId: 1, projectId: 1
		user = Meteor.users.findOne userId, fields: _id: 1

		if Meteor.isClient
			Meteor.subscribe 'userStatistics', userId, shiftId

		if Meteor.isServer
			check userId, isExistingUser
			check { shiftId: shiftId, teamId: teamId }, isExistingShiftAndTeam

			for team in shift.teams when team._id == teamId
				for participant in team.participants
					if participant._id == userId
						if !participant.thisTeamleader
							if Roles.userIsInRole participant._id, Permissions.teamleader, shift.tagId
								participant = participant
								participant.thisTeamleader = true

								Shifts.update _id: shiftId, 'teams._id': team._id,
									$pull: 'teams.$.participants': _id: userId

								Shifts.update _id: shiftId, 'teams._id': team._id,
									$addToSet: 'teams.$.participants': participant
							else
								throw new Meteor.Error 500, TAPi18n.__('modal.shift.noTeamleader')
						else
							throw new Meteor.Error 500, TAPi18n.__('modal.shift.alreadyTeamleader')
					else if participant.thisTeamleader
						participant.thisTeamleader = false

						Shifts.update _id: shiftId, 'teams._id': team._id,
							$pull: 'teams.$.participants': _id: participant._id

						Shifts.update _id: shiftId, 'teams._id': team._id,
							$addToSet: 'teams.$.participants': participant

				Meteor.call 'sendTeamUpdate', shiftId, teamId, 'leader'
				break

	addParticipant: (shiftId, teamId, userId) ->
		shift = Shifts.findOne shiftId, fields: teams: 1, tagId: 1, projectId: 1
		user = Meteor.users.findOne userId, fields:
			'profile.firstname': 1
			'profile.lastname': 1
			'profile.telefon': 1
			'profile.email': 1

		if Meteor.isClient
			Meteor.subscribe 'userStatistics', userId, shiftId

		if Meteor.isServer
			check userId, isExistingUser
			check { shiftId: shiftId, teamId: teamId }, isExistingShiftAndTeam
			check { projectId: shift.projectId, userId: Meteor.userId() }, isShiftScheduler
			check { tagId: shift.tagId, userId: userId }, isTagParticipant

			for team in shift.teams when team._id == teamId
				for notapprovedUser in team.declined.concat(team.pending) when notapprovedUser? && notapprovedUser._id == userId
					throw new Meteor.Error 500, TAPi18n.__('modal.addParticipant.alreadyRequested')

				for approvedUser in team.participants when approvedUser? && approvedUser._id == userId
					throw new Meteor.Error 500, TAPi18n.__('modal.addParticipant.alreadyParticipating')
				break

			user =
				_id: userId
				name: user.profile.firstname + ' ' + user.profile.lastname
				teamleader: Roles.userIsInRole userId, 'teamleader', shift.tagId
				substituteTeamleader: Roles.userIsInRole userId, 'substituteTeamleader', shift.tagId
				thisTeamleader: false
				phone: user.profile.telefon
				email: user.profile.email

			for team in shift.teams when team._id != teamId
				if userId in team.participants
					Meteor.call 'declineParticipant', shiftId, team._id, userId
				else if userId in team.pending
					Shifts.update _id: shiftId, 'teams._id': team._id,
						$pull: 'teams.$.pending': _id: userId
						$addToSet: 'teams.$.declined': user

			Shifts.update _id: shiftId, 'teams._id': teamId,
				$pull: 'teams.$.declined': _id: userId
				$addToSet: 'teams.$.pending': user
