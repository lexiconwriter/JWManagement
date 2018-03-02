import Users from '/imports/api/users/users.js';

Template['user.details'].helpers({
    data() {
        return {
            getMethod: 'user.get',
            backLink: 'user.search',
            sections: [
                {
                    header: 'identificationSection',
                    contents: [
                        {
                            key: 'profile_firstname'
                        }, {
                            key: 'profile_lastname'
                        }, {
                            key: 'profile_email'
                        }, {
                            key: 'profile_telefon'
                        }, {
                            key: 'username'
                        }, {
                            key: 'profile_gender',
                            type: 'dropdown'
                        }, {
                            key: 'profile_bdate'
                        }, {
                            key: 'profile_pioneer',
                            type: 'dropdown'
                        }, {
                            key: 'profile_privilege',
                            type: 'dropdown'
                        }, {
                            key: 'profile_languages'
                        }
                    ],
                    actions: [
                        {
                            key: 'passwordChange',
                            type: 'link',
                            style: 'primary',
                            route: 'password.change'
                        },
                        {
                            key: 'userDelete',
                            type: 'link',
                            style: 'danger',
                            route: 'user.removeFromProject'
                        }
                    ]
                }
            ]
        }
    }
});
