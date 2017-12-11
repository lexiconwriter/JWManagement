import { Vessels } from '/imports/api/vessels/vessels.coffee'

import './publish/vessel.coffee'
import './publish/vessel.search.coffee'

const PersistenceManager = require('/imports/api/persistence/PersistenceManager.js');

Meteor.methods({
    'vessel.get': ({ vesselId }) => {
        return Projects.find({
            _id: { $in: GetGroupsForUser(Meteor.userId(), Permissions.member) }
        }, {
            fields: { vesselModule: 1, harbors: 1 }
        })
        .fetch()
        .filter((project) => project.vesselModule)
        .reduce(() => getExtendedVessel(vesselId), {});
    },
    'vessel.getField': ({ vesselId, key }) => {
        return Projects.find({
            _id: { $in: GetGroupsForUser(Meteor.userId(), Permissions.member) }
        }, {
            fields: { vesselModule: 1, harbors: 1 }
        })
        .fetch()
        .filter((project) => project.vesselModule)
        .reduce(() => getExtendedVessel(vesselId), {})[key];
    },
    'vessel.insert': ({}, vessel) => {
        const project = Projects.findOne(projectId, {
            fields: {
                vesselModule: 1,
                harbors: 1
            }
        });

        if (project != null && project.vesselModule) {
            try {
                new PersistenceManager(Vessels).insert(vessel);
                return vessel._id;
            } catch(e) {
                throw new Meteor.Error(e);
            }
        }
    },
    'vessel.update': (vesselId, key, value) => {
        const project = Projects.findOne(projectId, {
            fields: {
                vesselModule: 1,
                harbors: 1
            }
        });

        if (project != null && project.vesselModule) {
            try {
                new PersistenceManager(Vessels).update(vesselId, key, value);
            } catch(e) {
                throw new Meteor.Error(e);
            }
        }
    },
    'vessel.visit.insert': ({ projectId, vesselId }, visit) => {
        const project = Projects.findOne(projectId, {
            fields: {
                vesselModule: 1,
                harbors: 1
            }
        });

        if (project != null && project.vesselModule) {
            const visits = Vessels.findOne(vesselId).visits;

            visit.projectId = projectId;
            delete visit.userId
            visits.push(visit);

            try {
                new PersistenceManager(Vessels).update(vessel._id, 'visits', visits);
                return vessel._id;
            } catch(e) {
                throw new Meteor.Error(e);
            }
        }
    },
    'vessel.visit.getAvailableHarbors': ({ projectId }) => {
        return Projects.find(projectId, {
            fields: {
                vesselModule: 1,
                harbors: 1
            }
        })
        .fetch()
        .filter((project) => project.vesselModule)
        .reduce((acc, project) => acc.concat(project.harbors), [])
        .map(({_id, name}) => { return { key: _id, value: name } });
    },
    'vessel.visit.getLast': ({ vesselId }) => {
        return Projects.find({
            _id: { $in: GetGroupsForUser(Meteor.userId(), Permissions.member) }
        }, {
            fields: { vesselModule: 1, harbors: 1 }
        })
        .fetch()
        .filter((project) => project.vesselModule)
        .reduce(() => getExtendedVessel(vesselId).visits, [])
        .pop();
    }
});

function getExtendedVessel(vesselId) {
    let vessel = Vessels.findOne(vesselId);

    if (vessel != undefined) {
        if ('visits' in vessel) {
            if (vessel.visits.length > 1) {
                vessel.visits.sort((a, b) => {
                    return a.date - b.date;
                });
                vessel.visits = [vessel.visits.pop()];
            }

            if (vessel.visits.length > 0) {
                if (vessel.visits[0].isUserVisible) {
                    const author = Meteor.users.findOne(vessel.visits[0].createdBy, {
                        fields: {
                            'profile.firstname': 1,
                            'profile.lastname': 1,
                            'profile.telefon': 1,
                            'profile.email': 1
                        }
                    });

                    vessel.visits[0].person = author.profile.firstname + ' ' + author.profile.lastname;
                    vessel.visits[0].email = author.profile.email;
                    vessel.visits[0].phone = author.profile.telefon;
                } else {
                    vessel.visits[0].person = 'Not visible';
                    vessel.visits[0].email = '';
                    vessel.visits[0].phone = '';
                }

                const project = Projects.findOne(vessel.visits[0].projectId, {
                    fields: {
                        country: 1,
                        harborGroup: 1,
                        harbors: 1
                    }
                });

                vessel.visits[0].country = project.country;
                vessel.visits[0].harborGroup = project.harborGroup;

                vessel.visits[0].harbor = project.harbors.filter((harbor) => {
                    return harbor._id == vessel.visits[0].harborId;
                })[0].name;
            }
        } else {
            vessel.visits = [];
        }
}

    return vessel;
}
